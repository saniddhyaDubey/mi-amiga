import AVFoundation
import Foundation

/// Speaks Spanish text with `AVSpeechSynthesizer`.
///
/// Voice selection prefers, in order: an enhanced/premium es-ES voice the user
/// has downloaded, then any es-ES voice, then any Spanish voice at all. Apple
/// ships only a compact es-ES voice by default; the premium ones sound markedly
/// better and the UI points people at the Settings path to get them.
@MainActor
@Observable
final class SpeechSpeaker: NSObject {

    private(set) var isSpeaking: Bool = false

    private let synthesizer = AVSpeechSynthesizer()

    /// True when the only Spanish voice available is the default compact one,
    /// so the UI can offer a one-time hint about downloading a better voice.
    var isUsingCompactVoice: Bool {
        guard let voice = Self.preferredSpanishVoice() else { return false }
        return voice.quality == .default
    }

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Half speed, for picking apart how a word is actually built.
    func speakSlowly(_ text: String) {
        speak(text, rate: AVSpeechUtteranceDefaultSpeechRate * 0.45)
    }

    func speak(_ text: String) {
        speak(text, rate: AVSpeechUtteranceDefaultSpeechRate * 0.92)
    }

    private func speak(_ text: String, rate: Float) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Tapping replay while it's mid-sentence should restart, not queue.
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        configurePlaybackSession()

        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = Self.preferredSpanishVoice()
        // Slightly under default: translated phrases are usually said to
        // someone who is listening carefully, not skimming.
        utterance.rate = rate
        utterance.pitchMultiplier = 1.0
        utterance.postUtteranceDelay = 0.1

        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    private func configurePlaybackSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(
            .playback,
            mode: .spokenAudio,
            options: [.duckOthers]
        )
        try? session.setActive(true)
    }

    /// Best available Spanish voice, preferring higher quality tiers.
    static func preferredSpanishVoice() -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices()

        let spanishSpain = voices.filter { $0.language == "es-ES" }
        let anySpanish = voices.filter { $0.language.hasPrefix("es") }

        // `.premium` and `.enhanced` are user-downloaded; rank them first.
        func best(_ candidates: [AVSpeechSynthesisVoice]) -> AVSpeechSynthesisVoice? {
            candidates.max { lhs, rhs in
                rank(lhs.quality) < rank(rhs.quality)
            }
        }

        return best(spanishSpain)
            ?? best(anySpanish)
            ?? AVSpeechSynthesisVoice(language: "es-ES")
    }

    private static func rank(_ quality: AVSpeechSynthesisVoiceQuality) -> Int {
        switch quality {
        case .premium: return 3
        case .enhanced: return 2
        case .default: return 1
        @unknown default: return 0
        }
    }
}

extension SpeechSpeaker: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didStart utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in self.isSpeaking = true }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in self.isSpeaking = false }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in self.isSpeaking = false }
    }
}
