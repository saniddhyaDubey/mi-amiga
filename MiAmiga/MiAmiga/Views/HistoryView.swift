import SwiftUI

/// Past phrases, newest first, each replayable.
struct HistoryView: View {
    let model: TranslatorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingClear = false

    var body: some View {
        NavigationStack {
            Group {
                if model.history.isEmpty {
                    ContentUnavailableView(
                        "No phrases yet",
                        systemImage: "clock",
                        description: Text("Phrases you translate will show up here.")
                    )
                } else {
                    List {
                        ForEach(model.history) { phrase in
                            row(phrase)
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                model.delete(model.history[index])
                            }
                        }
                    }
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear", role: .destructive) {
                        confirmingClear = true
                    }
                    .disabled(model.history.isEmpty)
                }
            }
            .confirmationDialog(
                "Clear all phrases?",
                isPresented: $confirmingClear,
                titleVisibility: .visible
            ) {
                Button("Clear All", role: .destructive) {
                    model.clearHistory()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This can't be undone.")
            }
        }
    }

    private func row(_ phrase: Phrase) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(phrase.spanish)
                    .font(.body.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
                Text(phrase.english)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Button {
                model.speak(phrase)
            } label: {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.body)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Play \(phrase.spanish) in Spanish")
        }
        .padding(.vertical, 4)
    }
}
