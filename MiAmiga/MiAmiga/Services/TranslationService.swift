import Foundation
import Translation

/// English → Spanish translation state on top of Apple's on-device
/// `Translation` framework.
///
/// This type deliberately does **not** hold the `TranslationSession`.
/// `TranslationSession` is a non-`Sendable` class that SwiftUI vends to the
/// `.translationTask` closure and keeps alive only for that closure's lifetime;
/// storing it on a `@MainActor` object and awaiting through it would send it
/// across an isolation boundary, which Swift 6 rejects. So the session stays in
/// the closure, and this type holds only the request text and the result — both
/// `Sendable` — plus the UI-facing status flags.
@MainActor
@Observable
final class TranslationService {

    enum TranslationError: LocalizedError {
        case sessionUnavailable
        case languagePairUnsupported
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .sessionUnavailable:
                return "Translation isn't ready yet. Give it a moment and try again."
            case .languagePairUnsupported:
                return "English to Spanish translation isn't available on this device."
            case .failed(let detail):
                return "Translation failed: \(detail)"
            }
        }
    }

    static let source = Locale.Language(identifier: "en-US")
    static let target = Locale.Language(identifier: "es-ES")

    private(set) var isTranslating: Bool = false
    private(set) var error: TranslationError?

    /// Set once `.translationTask` has handed us a live session.
    private(set) var isReady: Bool = false

    /// The phrase awaiting translation. Changing it re-triggers the
    /// `.translationTask` closure, which is what picks the phrase up.
    private(set) var pendingText: String?

    /// Result of the most recent translation, consumed by the view model.
    private(set) var lastResult: String?

    /// Resumed by the translation closure when a result (or failure) lands, so
    /// the view model can await instead of poll.
    private var waiter: CheckedContinuation<String?, Never>?

    // MARK: - Driving a translation

    /// Queues a phrase and waits for the `.translationTask` closure to finish
    /// it. Returns nil on failure.
    func translate(_ text: String) async -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        lastResult = nil
        error = nil
        isTranslating = true

        return await withCheckedContinuation { continuation in
            waiter = continuation
            // Setting this triggers the view's onChange, which invalidates the
            // task configuration and re-runs the translation closure.
            pendingText = trimmed
        }
    }

    /// Called from the translation closure once a session exists.
    func markReady() {
        isReady = true
    }

    func markNotReady() {
        isReady = false
    }

    /// Consumes the pending request so the closure doesn't translate it twice.
    func takePendingText() -> String? {
        defer { pendingText = nil }
        return pendingText
    }

    func finish(_ spanish: String) {
        lastResult = spanish
        isTranslating = false
        error = nil
        waiter?.resume(returning: spanish)
        waiter = nil
    }

    func fail(_ message: String) {
        lastResult = nil
        isTranslating = false
        error = .failed(message)
        waiter?.resume(returning: nil)
        waiter = nil
    }

    func failUnavailable() {
        lastResult = nil
        isTranslating = false
        error = .sessionUnavailable
        waiter?.resume(returning: nil)
        waiter = nil
    }

    /// Whether the device can do en→es at all, independent of whether the pack
    /// is downloaded yet. Used to fail loudly at launch rather than at first use.
    static func isPairSupported() async -> Bool {
        let availability = LanguageAvailability()
        let status = await availability.status(from: source, to: target)
        switch status {
        case .installed, .supported:
            return true
        case .unsupported:
            return false
        @unknown default:
            return false
        }
    }
}
