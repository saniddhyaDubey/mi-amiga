import SwiftData
import SwiftUI

/// Everything you've saved, plus the built-in packs, grouped by category.
/// Tap a phrase to practise saying it.
struct LibraryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \SavedPhrase.createdAt, order: .reverse) private var phrases: [SavedPhrase]

    @State private var practicing: SavedPhrase?
    @State private var selectedCategory: String?

    /// "Starred" collects everything you saved yourself; the rest come from packs.
    private var categories: [String] {
        let packOrder = PhrasePacks.all.map(\.category)
        let present = Set(phrases.compactMap { $0.category })
        let ordered = packOrder.filter(present.contains)
        return (phrases.contains { $0.category == nil } ? ["Starred"] : []) + ordered
    }

    private var visiblePhrases: [SavedPhrase] {
        guard let selectedCategory else { return phrases }
        if selectedCategory == "Starred" {
            return phrases.filter { $0.category == nil }
        }
        return phrases.filter { $0.category == selectedCategory }
    }

    var body: some View {
        NavigationStack {
            Group {
                if phrases.isEmpty {
                    ContentUnavailableView(
                        "Nothing saved yet",
                        systemImage: "star",
                        description: Text("Star a translation, and it'll show up here to practise.")
                    )
                } else {
                    list
                }
            }
            .navigationTitle("Phrases")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $practicing) { phrase in
                PracticeView(
                    english: phrase.english,
                    spanish: phrase.spanish
                ) { passed in
                    phrase.recordAttempt(success: passed)
                }
            }
        }
    }

    private var list: some View {
        VStack(spacing: 0) {
            categoryPicker

            List {
                ForEach(visiblePhrases) { phrase in
                    row(phrase)
                }
                .onDelete(perform: delete)
            }
            .listStyle(.plain)
        }
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: "All", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(categories, id: \.self) { category in
                    chip(
                        title: category,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(.bar)
    }

    private func chip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule().fill(
                        isSelected
                            ? Color.miAmiga.opacity(0.18)
                            : Color(.secondarySystemFill).opacity(0.6)
                    )
                )
                .foregroundStyle(isSelected ? Color.miAmiga : .primary)
        }
        .buttonStyle(.plain)
    }

    private func row(_ phrase: SavedPhrase) -> some View {
        Button {
            practicing = phrase
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(phrase.spanish)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(phrase.english)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let accuracy = phrase.accuracy {
                    Text("\(Int(accuracy * 100))%")
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(accuracy >= 0.7 ? .green : .orange)
                }

                Image(systemName: "mic.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.miAmiga)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 2)
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            context.delete(visiblePhrases[index])
        }
    }
}
