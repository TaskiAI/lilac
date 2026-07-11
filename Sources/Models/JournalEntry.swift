import Foundation
import SwiftData

/// A typed journal entry — the place to reflect between sessions. v2's edge over
/// a plain journal is the therapy coupling: an entry can carry a `prompt`
/// (a therapy-aware question that seeded it) and a `linkedSession` (the session
/// it reflects on), so reflection is grounded in what was actually discussed.
@Model
final class JournalEntry {
    var createdAt: Date
    var title: String
    var text: String

    /// The therapy-aware question that seeded this entry, if any (shown above the
    /// body in the editor). Empty for a blank entry. Non-optional with a default,
    /// so it's lightweight-migration-safe.
    var prompt: String = ""

    /// The session this entry reflects on, if any. Optional to-one relationship;
    /// deleting a session nullifies the link (reflections are kept).
    var linkedSession: TherapySession? = nil

    init(
        createdAt: Date = .now,
        title: String = "",
        text: String = "",
        prompt: String = "",
        linkedSession: TherapySession? = nil
    ) {
        self.createdAt = createdAt
        self.title = title
        self.text = text
        self.prompt = prompt
        self.linkedSession = linkedSession
    }

    /// A display title: the user's title, else the first line of the body, else
    /// the prompt, else a fallback.
    var displayTitle: String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        if !trimmedTitle.isEmpty { return trimmedTitle }

        let firstLine = text
            .split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: true)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespaces) ?? ""
        if !firstLine.isEmpty { return String(firstLine.prefix(60)) }

        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespaces)
        if !trimmedPrompt.isEmpty { return String(trimmedPrompt.prefix(60)) }

        return "Untitled"
    }
}
