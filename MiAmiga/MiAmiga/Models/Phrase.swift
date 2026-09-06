import Foundation

/// One completed English → Spanish exchange, kept so the user can scroll back
/// and replay something they said a minute ago.
struct Phrase: Identifiable, Hashable, Codable {
    let id: UUID
    let english: String
    let spanish: String
    let createdAt: Date

    init(id: UUID = UUID(), english: String, spanish: String, createdAt: Date = .now) {
        self.id = id
        self.english = english
        self.spanish = spanish
        self.createdAt = createdAt
    }
}
