import SwiftData
import SwiftUI

@main
struct MiAmigaApp: App {
    private let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: SavedPhrase.self)
        } catch {
            // Nothing sensible to fall back to — an app that can't open its
            // own store can't save anything.
            fatalError("Couldn't open the phrase store: \(error)")
        }
        Self.seedIfNeeded(container.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(.miAmiga)
        }
        .modelContainer(container)
    }

    /// Loads the built-in packs the first time the app runs. Keyed on a flag
    /// rather than an empty store, so deleting every phrase doesn't cause the
    /// packs to silently reappear.
    private static func seedIfNeeded(_ context: ModelContext) {
        let key = "mi-amiga.didSeedPacks"
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        for entry in PhrasePacks.seedPhrases {
            context.insert(
                SavedPhrase(
                    english: entry.english,
                    spanish: entry.spanish,
                    category: entry.category
                )
            )
        }

        do {
            try context.save()
            UserDefaults.standard.set(true, forKey: key)
        } catch {
            // Leave the flag unset so seeding is retried next launch.
        }
    }
}
