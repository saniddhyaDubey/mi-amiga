import SwiftUI

/// Say the Spanish yourself and see how close you got.
///
/// Shown as a sheet over either a fresh translation or a saved phrase. The
/// target is always visible — this is a speaking drill, not a memory test.
struct PracticeView: View {
    let english: String
    let spanish: String
    /// Called with whether the attempt passed, so callers can record progress.
    var onAttempt: ((Bool) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var recognizer = SpeechRecognizer()
    @State private var speaker = SpeechSpeaker()
    @State private var result: PronunciationScorer.Result?
    @State private var isListening = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    prompt
                    targetPhrase

                    if let result {
                        scoreCard(result)
                    }

                    Spacer(minLength: 8)
                }
                .padding(20)
            }
            .safeAreaInset(edge: .bottom) { micArea }
            .navigationTitle("Practice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onDisappear {
            speaker.stop()
            if recognizer.isListening { _ = recognizer.stopListening() }
        }
    }

    // MARK: - Pieces

    private var prompt: some View {
        VStack(spacing: 6) {
            Text("Say this out loud")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(english)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var targetPhrase: some View {
        VStack(spacing: 16) {
            // Words light up green or red once scored.
            Group {
                if let result {
                    scoredText(result)
                } else {
                    Text(spanish)
                        .font(.system(.title, design: .rounded, weight: .semibold))
                }
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Button {
                    speaker.speak(spanish)
                } label: {
                    Label("Listen", systemImage: "speaker.wave.2.fill")
                }
                Button {
                    speaker.speakSlowly(spanish)
                } label: {
                    Label("Slowly", systemImage: "tortoise.fill")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    /// The target phrase with each word tinted by whether it was matched.
    private func scoredText(_ result: PronunciationScorer.Result) -> some View {
        var composed = Text("")
        for (index, entry) in result.words.enumerated() {
            if index > 0 { composed = composed + Text(" ") }
            composed = composed + Text(entry.word)
                .foregroundColor(entry.matched ? .green : .red)
        }
        return composed
            .font(.system(.title, design: .rounded, weight: .semibold))
    }

    private func scoreCard(_ result: PronunciationScorer.Result) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: result.isPass ? "checkmark.circle.fill" : "arrow.clockwise.circle.fill")
                    .foregroundStyle(result.isPass ? .green : .orange)
                    .font(.title2)
                Text(result.isPass ? "Nice one" : "Close — try again")
                    .font(.headline)
                Spacer()
                Text("\(Int(result.score * 100))%")
                    .font(.title3.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if !result.heard.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("What I heard")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(result.heard)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private var micArea: some View {
        VStack(spacing: 8) {
            MicButton(
                isListening: isListening,
                level: recognizer.audioLevel,
                onPress: { Task { await startAttempt() } },
                onRelease: { Task { await finishAttempt() } }
            )

            Text(isListening ? "Release when you're done" : "Hold and say it in Spanish")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let error = recognizer.error?.errorDescription {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }

    // MARK: - Flow

    private func startAttempt() async {
        speaker.stop()
        result = nil
        recognizer.setLanguage(.spanish)
        await recognizer.startListening()
        isListening = recognizer.isListening
    }

    private func finishAttempt() async {
        guard isListening else { return }
        isListening = false

        let heard = recognizer.stopListening()
        guard !heard.isEmpty else { return }

        let scored = PronunciationScorer.score(heard: heard, target: spanish)
        result = scored
        onAttempt?(scored.isPass)
    }
}
