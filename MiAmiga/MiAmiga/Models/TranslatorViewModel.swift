import Foundation
import Observation
import Translation

/// Owns the speak → transcribe → translate → (optionally) speak flow and the
/// history of past phrases.
@MainActor
@Observable
final class TranslatorViewModel {

    enum Stage: Equatable {
        case idle
        case listening
        case translating
        case done
    }

    let recognizer = SpeechRecognizer()
    let speaker = SpeechSpeaker()
    let translator = TranslationService()

    private(set) var stage: Stage = .idle
    private(set) var history: [Phrase] = []

    /// The phrase currently on screen in the big card.
    private(set) var current: Phrase?

    /// Live partial transcript while the user is holding the button.
    var livePartial: String { recognizer.transcript }

    var audioLevel: Float { recognizer.audioLevel }
    var isSpeaking: Bool { speaker.isSpeaking }

    /// Set when translation is unsupported on this device entirely.
    private(set) var fatalMessage: String?

    /// Any recoverable error worth showing in the UI.
    var errorMessage: String? {
        recognizer.error?.errorDescription ?? translator.error?.errorDescription
    }

    // MARK: - Lifecycle

    func onAppear() async {
        if await TranslationService.isPairSupported() == false {
            fatalMessage = "This device can't translate English to Spanish. That usually means the Translation framework isn't available in your region or iOS version."
        }
        loadHistory()
    }


    // MARK: - The main flow

    func beginListening() async {
        guard stage == .idle || stage == .done else { return }
        speaker.stop()
        current = nil
        stage = .listening
        await recognizer.startListening()

        // startListening bails without flipping isListening when a permission
        // was refused; don't strand the UI in a listening state it never entered.
        if !recognizer.isListening {
            stage = .idle
        }
    }

    func endListeningAndTranslate() async {
        guard stage == .listening else { return }

        let english = recognizer.stopListening()
        guard !english.isEmpty else {
            stage = .idle
            return
        }

        stage = .translating

        guard let spanish = await translator.translate(english) else {
            // Keep what they said on screen even when translation failed, so a
            // retry doesn't mean saying the whole sentence again.
            current = Phrase(english: english, spanish: "")
            stage = .done
            return
        }

        let phrase = Phrase(english: english, spanish: spanish)
        current = phrase
        history.insert(phrase, at: 0)
        saveHistory()
        stage = .done
    }

    /// Retries translation for a phrase whose first attempt failed.
    func retryTranslation() async {
        guard let english = current?.english, !english.isEmpty else { return }
        stage = .translating

        guard let spanish = await translator.translate(english) else {
            stage = .done
            return
        }

        let phrase = Phrase(english: english, spanish: spanish)
        current = phrase
        history.insert(phrase, at: 0)
        saveHistory()
        stage = .done
    }

    // MARK: - Playback

    func speakCurrent() {
        guard let spanish = current?.spanish, !spanish.isEmpty else { return }
        speaker.speak(spanish)
    }

    func speakCurrentSlowly() {
        guard let spanish = current?.spanish, !spanish.isEmpty else { return }
        speaker.speakSlowly(spanish)
    }

    func speak(_ phrase: Phrase) {
        speaker.speak(phrase.spanish)
    }

    func stopSpeaking() {
        speaker.stop()
    }

    // MARK: - History

    func clearHistory() {
        history.removeAll()
        saveHistory()
    }

    func delete(_ phrase: Phrase) {
        history.removeAll { $0.id == phrase.id }
        saveHistory()
    }

    private static let historyKey = "mi-amiga.history"
    private static let historyLimit = 100

    private func saveHistory() {
        let trimmed = Array(history.prefix(Self.historyLimit))
        guard let data = try? JSONEncoder().encode(trimmed) else { return }
        UserDefaults.standard.set(data, forKey: Self.historyKey)
    }

    private func loadHistory() {
        guard
            let data = UserDefaults.standard.data(forKey: Self.historyKey),
            let decoded = try? JSONDecoder().decode([Phrase].self, from: data)
        else { return }
        history = decoded
    }
}
