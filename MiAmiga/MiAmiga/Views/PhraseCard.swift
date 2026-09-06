import SwiftUI

/// The main result card: English on top, Spanish below in the larger type,
/// with a speak button. Spanish gets visual priority because it's the thing
/// you're showing or reading to someone else.
struct PhraseCard: View {
    let english: String
    let spanish: String
    let isSpeaking: Bool
    let isTranslating: Bool
    let onSpeak: () -> Void
    let onStop: () -> Void
    let onRetry: () -> Void

    private var translationFailed: Bool {
        !english.isEmpty && spanish.isEmpty && !isTranslating
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // English
            VStack(alignment: .leading, spacing: 6) {
                Label("English", systemImage: "quote.opening")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .labelStyle(.titleOnly)

                Text(english)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            // Spanish
            VStack(alignment: .leading, spacing: 10) {
                Text("Español")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.miAmiga)

                if isTranslating {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Translating…")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                } else if translationFailed {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Couldn't translate that one.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                        Button("Try again", systemImage: "arrow.clockwise", action: onRetry)
                            .buttonStyle(.bordered)
                    }
                } else {
                    Text(spanish)
                        .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }

            if !spanish.isEmpty {
                Button(action: isSpeaking ? onStop : onSpeak) {
                    Label(
                        isSpeaking ? "Stop" : "Hear it in Spanish",
                        systemImage: isSpeaking ? "stop.fill" : "speaker.wave.2.fill"
                    )
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .contentTransition(.symbolEffect(.replace))
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}
