import AVFoundation
import Foundation
import Speech

/// Wraps `SFSpeechRecognizer` + an `AVAudioEngine` tap to provide live
/// English dictation while the user holds the mic button.
///
/// The recognizer is forced on-device when the device supports it, so a phrase
/// never leaves the phone. `SFSpeechRecognizer` silently falls back to Apple's
/// servers when `requiresOnDeviceRecognition` is false, which we don't want for
/// a translator people may use on hotel wifi.
@MainActor
@Observable
final class SpeechRecognizer {

    enum RecognizerError: LocalizedError {
        case notAuthorized
        case micNotAuthorized
        case recognizerUnavailable
        case audioSessionFailed(String)

        var errorDescription: String? {
            switch self {
            case .notAuthorized:
                return "Speech recognition permission was denied. Enable it in Settings › Mi Amiga › Speech Recognition."
            case .micNotAuthorized:
                return "Microphone access was denied. Enable it in Settings › Mi Amiga › Microphone."
            case .recognizerUnavailable:
                return "Speech recognition isn't available for that language on this device right now."
            case .audioSessionFailed(let detail):
                return "Couldn't start the microphone: \(detail)"
            }
        }
    }

    /// Text recognized so far in the current utterance. Updates live.
    private(set) var transcript: String = ""
    private(set) var isListening: Bool = false
    private(set) var error: RecognizerError?

    /// Peak input level 0...1, used to drive the waveform ring in the UI.
    private(set) var audioLevel: Float = 0

    /// Which language the mic is currently listening for. English for
    /// translating, Spanish for practice — a recognizer's locale is fixed at
    /// construction, so switching means building a new one.
    enum Language: String {
        case english = "en-US"
        case spanish = "es-ES"
    }

    private(set) var language: Language = .english
    private var recognizer = SFSpeechRecognizer(locale: Locale(identifier: Language.english.rawValue))

    /// Switches the listening language. No-op while listening, so a language
    /// change can't yank the recognizer out from under a live utterance.
    func setLanguage(_ language: Language) {
        guard !isListening, language != self.language else { return }
        self.language = language
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: language.rawValue))
    }

    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let engine = AVAudioEngine()

    /// Bumped on every start/stop. Callbacks from the audio tap and the
    /// recognition task capture the value current when they were installed and
    /// drop themselves if it has moved on, so a slow callback from the previous
    /// utterance can't write into the next one.
    private var generation: UInt64 = 0

    /// Mutable state touched from the realtime audio thread, so it can't live
    /// on the main actor. A lock keeps it well-defined under Swift 6 checking.
    private final class Throttle: @unchecked Sendable {
        private let lock = NSLock()
        private var storage: CFAbsoluteTime = 0
        var value: CFAbsoluteTime {
            get { lock.withLock { storage } }
            set { lock.withLock { storage = newValue } }
        }
    }

    // MARK: - Permissions

    /// Requests both permissions up front. Returns true only if both are granted.
    func requestPermissions() async -> Bool {
        let speechOK = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        guard speechOK else {
            error = .notAuthorized
            return false
        }

        let micOK = await AVAudioApplication.requestRecordPermission()
        guard micOK else {
            error = .micNotAuthorized
            return false
        }

        error = nil
        return true
    }

    // MARK: - Capture

    func startListening() async {
        guard !isListening else { return }
        guard await requestPermissions() else { return }
        guard let recognizer, recognizer.isAvailable else {
            error = .recognizerUnavailable
            return
        }

        // A fresh transcript per utterance; the previous one has already been
        // handed to the translator by the time we get here.
        transcript = ""
        error = nil

        do {
            try configureAudioSession()
        } catch {
            self.error = .audioSessionFailed(error.localizedDescription)
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        // Keep audio on-device when the hardware can manage it.
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        self.request = request

        generation &+= 1
        let generation = self.generation
        let lastLevelUpdate = Throttle()

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)

        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)

            // The tap fires ~40x/sec. Spawning a main-actor Task per buffer is
            // wasteful, and a late hop can land after stopListening() has zeroed
            // the level — leaving the ring lit after release. Throttle, and let
            // the generation check drop anything from a finished session.
            let level = Self.peakLevel(of: buffer)
            let now = CFAbsoluteTimeGetCurrent()
            guard now - lastLevelUpdate.value >= 0.05 else { return }
            lastLevelUpdate.value = now

            Task { @MainActor [weak self] in
                guard let self, self.isListening, self.generation == generation else { return }
                self.audioLevel = level
            }
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            self.error = .audioSessionFailed(error.localizedDescription)
            return
        }

        isListening = true

        task = recognizer.recognitionTask(with: request) { [weak self] result, taskError in
            Task { @MainActor [weak self] in
                guard let self, self.generation == generation else { return }
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                }
                // A cancelled task reports an error we deliberately swallow —
                // the user releasing the button is a normal end, not a failure.
                if taskError != nil, self.isListening {
                    self.stopListening()
                }
            }
        }
    }

    /// Ends capture and returns the final transcript, trimmed. Empty string if
    /// nothing was heard.
    @discardableResult
    func stopListening() -> String {
        guard isListening else {
            return transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Invalidate in-flight callbacks before tearing down, so nothing from
        // this utterance writes state after we've zeroed it.
        generation &+= 1
        isListening = false
        audioLevel = 0

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()

        request?.endAudio()
        task?.finish()
        request = nil
        task = nil

        // Hand the mic back so playback isn't stuck in a record-friendly route.
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )

        return transcript.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Helpers

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        // `.playAndRecord` rather than `.record` so the Spanish playback that
        // follows doesn't need a session category swap mid-flow.
        try session.setCategory(
            .playAndRecord,
            mode: .spokenAudio,
            options: [.duckOthers, .defaultToSpeaker, .allowBluetoothHFP]
        )
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    /// Peak amplitude of a buffer, normalized to a 0...1 range suitable for UI.
    private nonisolated static func peakLevel(of buffer: AVAudioPCMBuffer) -> Float {
        guard let channel = buffer.floatChannelData?[0] else { return 0 }
        let count = Int(buffer.frameLength)
        guard count > 0 else { return 0 }

        var peak: Float = 0
        for index in 0..<count {
            peak = max(peak, abs(channel[index]))
        }
        // Speech rarely approaches full scale; scale up so the ring actually moves.
        return min(peak * 3.5, 1)
    }
}
