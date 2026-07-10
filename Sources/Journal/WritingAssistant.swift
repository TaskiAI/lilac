import Foundation

/// Offers a few short directions to help a writer continue when they pause or
/// start blank — pointed at what the entry is *lacking* (an unnamed feeling, a
/// concrete detail, the "why", what's next). It never writes, summarizes, or
/// judges the entry; the suggestions are read, then the writer writes by hand.
///
/// Uses DeepSeek when configured (so the nudges reflect what's actually there),
/// and falls back to curated openers/continuations offline. Gated by
/// `enabledKey` at the call site.
enum WritingAssistant {
    static let enabledKey = "assist.enabled"

    /// Up to 3 short nudges. `currentText` is the recognized-so-far text (may be
    /// empty for a fresh page).
    static func suggestions(prompt: String, currentText: String) async -> [String] {
        let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        if DeepSeekClient.shared.isConfigured,
           let ai = await aiSuggestions(prompt: prompt, currentText: trimmed), !ai.isEmpty {
            return Array(ai.prefix(3))
        }
        return fallback(isEmpty: trimmed.isEmpty)
    }

    // MARK: DeepSeek

    private static func aiSuggestions(prompt: String, currentText: String) async -> [String]? {
        let system = """
        You gently help someone who paused while journaling. Look at what they've \
        written and suggest UP TO 3 short directions to continue — each a brief \
        question or nudge (max 12 words) aimed at what's MISSING: an unnamed \
        feeling, a concrete detail, the "why", or what comes next. If they've \
        written nothing yet, offer gentle ways to begin. Never write, complete, \
        summarize, or judge their entry. Respond ONLY with a JSON array of \
        strings, e.g. ["...","...","..."].
        """
        var user = ""
        if !prompt.isEmpty { user += "Their prompt: \(prompt)\n\n" }
        user += "What they've written so far:\n"
        user += currentText.isEmpty ? "(nothing yet)" : currentText

        guard let raw = try? await DeepSeekClient.shared.complete(system: system, user: user, maxTokens: 160),
              let array = parseArray(raw) else {
            return nil
        }
        return array
    }

    private static func parseArray(_ raw: String) -> [String]? {
        guard let start = raw.firstIndex(of: "["), let end = raw.lastIndex(of: "]"), start < end else {
            return nil
        }
        let json = String(raw[start...end])
        guard let data = json.data(using: .utf8),
              let items = try? JSONSerialization.jsonObject(with: data) as? [String] else {
            return nil
        }
        let cleaned = items
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return cleaned.isEmpty ? nil : cleaned
    }

    // MARK: Offline fallback

    private static func fallback(isEmpty: Bool) -> [String] {
        let pool = isEmpty ? openers : continuations
        return Array(pool.shuffled().prefix(3))
    }

    private static let openers = [
        "What's most on your mind right now?",
        "Describe how today actually felt.",
        "What moment keeps replaying?",
        "Name one thing you're avoiding.",
        "Start with where you are, literally."
    ]

    private static let continuations = [
        "What were you feeling as this happened?",
        "Add one concrete detail you left out.",
        "Why does this matter to you?",
        "What's underneath that?",
        "What would you do differently?",
        "Who else was part of this?",
        "What do you need right now?"
    ]
}
