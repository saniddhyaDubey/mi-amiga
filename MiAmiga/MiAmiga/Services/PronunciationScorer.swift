import Foundation

/// Compares what you said against the target Spanish, word by word.
///
/// Deliberately forgiving: the recognizer often drops accents, returns digits
/// for spoken numbers, and punctuates however it likes. None of that means you
/// said the phrase wrong, so all of it is normalized away before comparing.
///
/// What this measures is *word accuracy* — did you say the right words. It is
/// not a phonetic assessment: `SFSpeechRecognizer` reports its best guess at
/// your words, so a heavy accent that still resolves to the right word scores
/// as correct. Treat a high score as "you said the right thing", not "you
/// sounded like a native".
enum PronunciationScorer {

    struct Result {
        /// Each target word paired with whether you got it.
        let words: [(word: String, matched: Bool)]
        let heard: String

        /// Share of target words matched, 0...1.
        var score: Double {
            guard !words.isEmpty else { return 0 }
            return Double(words.filter(\.matched).count) / Double(words.count)
        }

        /// The bar for counting an attempt as a success.
        var isPass: Bool { score >= 0.7 }

        var missedWords: [String] {
            words.filter { !$0.matched }.map(\.word)
        }
    }

    static func score(heard: String, target: String) -> Result {
        // Split the target once, keeping the display form and its normalized
        // key together so the two can never drift out of alignment.
        let targetWords = target
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .map { (display: $0, key: normalize($0)) }
            .filter { !$0.key.isEmpty }

        // Match greedily but allow for words spoken out of order or a stray
        // extra word — a missing article shouldn't cascade into everything
        // after it being marked wrong.
        var remaining = tokenize(heard)
        var words: [(String, Bool)] = []

        for target in targetWords {
            if let hit = remaining.firstIndex(of: target.key) {
                remaining.remove(at: hit)
                words.append((target.display, true))
            } else {
                words.append((target.display, false))
            }
        }

        return Result(words: words, heard: heard)
    }

    /// Lowercases, strips accents and punctuation, and splits into words.
    private static func tokenize(_ text: String) -> [String] {
        text.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map(normalize)
            .filter { !$0.isEmpty }
    }

    /// The comparison key for a word: lowercased, accent-free, letters only.
    private static func normalize(_ word: String) -> String {
        word.folding(
            options: [.diacriticInsensitive, .caseInsensitive],
            locale: Locale(identifier: "es")
        )
        .components(separatedBy: CharacterSet.alphanumerics.inverted)
        .joined()
    }
}
