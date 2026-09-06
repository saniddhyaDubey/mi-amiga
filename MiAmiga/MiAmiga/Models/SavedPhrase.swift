import Foundation
import SwiftData

/// A phrase kept for practice — either starred from something you translated,
/// or seeded from one of the built-in packs.
@Model
final class SavedPhrase {
    var english: String = ""
    var spanish: String = ""
    var createdAt: Date = Date.now

    /// Which starter pack this came from, or nil if you starred it yourself.
    var category: String?

    /// How many times you've spoken it in practice, and how many of those
    /// the recognizer accepted. Enough to show progress without a full
    /// spaced-repetition model.
    var attemptCount: Int = 0
    var successCount: Int = 0
    var lastPracticedAt: Date?

    init(
        english: String,
        spanish: String,
        category: String? = nil,
        createdAt: Date = .now
    ) {
        self.english = english
        self.spanish = spanish
        self.category = category
        self.createdAt = createdAt
    }

    /// Share of attempts the recognizer matched, 0...1. Nil until you've tried.
    var accuracy: Double? {
        guard attemptCount > 0 else { return nil }
        return Double(successCount) / Double(attemptCount)
    }

    func recordAttempt(success: Bool) {
        attemptCount += 1
        if success { successCount += 1 }
        lastPracticedAt = .now
    }
}
