import Foundation
import SwiftData

/// A typed journal entry. v2 is a lean therapy companion: the journal is a plain
/// place to reflect between sessions — a title and a body of text, no handwriting,
/// formats, or prompts. (The differentiator to build next is wiring these to the
/// therapy sessions so entries can be prompted by what was discussed.)
@Model
final class JournalEntry {
    var createdAt: Date
    var title: String
    var text: String

    init(createdAt: Date = .now, title: String = "", text: String = "") {
        self.createdAt = createdAt
        self.title = title
        self.text = text
    }

    /// A display title: the user's title, else the first line of the body, else a date.
    var displayTitle: String {
        if !title.trimmingCharacters(in: .whitespaces).isEmpty { return title }
        let firstLine = text
            .split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: true)
            .first
            .map(String.init) ?? ""
        if !firstLine.trimmingCharacters(in: .whitespaces).isEmpty {
            return String(firstLine.prefix(60))
        }
        return "Untitled"
    }
}
