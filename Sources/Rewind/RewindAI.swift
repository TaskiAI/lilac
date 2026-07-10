import Foundation

/// The narrow DeepSeek calls the Rewind feature is allowed to make — nothing
/// else uses AI here. Every call fails gracefully: on any error it returns nil
/// and the caller proceeds without the AI's contribution (no bridge sentence,
/// no tags, and — for safety — an unscreened entry is treated conservatively by
/// `RewindEngine`).
///
/// Each result carries the raw `prompt`/`response` so the engine can write an
/// `AICallLog` on the main actor (keeping actor isolation clean).
enum RewindAI {
    struct Tags {
        let themes: [String]
        let salience: Double
        let prompt: String
        let response: String
    }

    struct Safety {
        let flagged: Bool
        let reason: String?
        let prompt: String
        let response: String
    }

    struct Bridge {
        let sentence: String
        let prompt: String
        let response: String
    }

    /// Per-entry classification (theme tags + coarse salience 1…5).
    static func tag(text: String) async -> Tags? {
        let system = """
        You tag a personal journal entry for a private journaling app. Respond \
        ONLY with JSON: {"themes": ["lowercase-hyphenated-tag", ...], "salience": 1-5}. \
        Give 1-4 short recurring-topic tags (e.g. "work-stress", "family", \
        "self-worth", "grief", "health"). "salience" is how emotionally significant \
        the entry reads, 1 (mundane) to 5 (pivotal). No prose, no preamble.
        """
        guard let raw = try? await DeepSeekClient.shared.complete(system: system, user: text, maxTokens: 200),
              let json = extractJSON(raw),
              let obj = try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any] else {
            return nil
        }
        let themes = (obj["themes"] as? [String])?.map(normalizeTag).filter { !$0.isEmpty } ?? []
        let salience = (obj["salience"] as? NSNumber)?.doubleValue ?? 3
        return Tags(themes: Array(themes.prefix(4)), salience: min(5, max(1, salience)),
                    prompt: text, response: raw)
    }

    /// Crisis/self-harm classification. Runs before an entry is ever queued for
    /// passive surfacing. On failure the caller treats the result as *unknown*.
    static func safety(text: String) async -> Safety? {
        let system = """
        You are a safety classifier. Given a journal entry, respond ONLY with JSON: \
        {"crisis_flagged": true|false, "reason": "short description or null"}. Flag \
        true if the entry contains explicit mention of self-harm, suicidal ideation, \
        or acute crisis content. Do not flag general sadness, anxiety, or difficult \
        emotions — only acute risk content.
        """
        guard let raw = try? await DeepSeekClient.shared.complete(system: system, user: text, maxTokens: 120),
              let json = extractJSON(raw),
              let obj = try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any],
              let flagged = obj["crisis_flagged"] as? Bool else {
            return nil
        }
        return Safety(flagged: flagged, reason: obj["reason"] as? String, prompt: text, response: raw)
    }

    /// One short, descriptive (non-diagnostic) bridge sentence connecting a past
    /// entry to the present. Returns nil on any failure.
    static func bridge(pastText: String, pastDate: Date, moodNote: String?) async -> Bridge? {
        let system = """
        You write a single short, warm, descriptive sentence (max 25 words) that \
        neutrally bridges a past journal entry and the present moment for the user. \
        Never diagnose, interpret motives, or use clinical language. Never say things \
        like "you were spiraling" — instead describe factually, e.g. "You wrote this \
        during a stressful week in March." If mood/sentiment data is available, you \
        may reference it factually. Respond with plain text only, no preamble.
        """
        let dateText = pastDate.formatted(.dateTime.month(.wide).day().year())
        var user = "Past entry (written \(dateText)):\n\(pastText)"
        if let moodNote { user += "\n\nMood note: \(moodNote)" }

        guard let raw = try? await DeepSeekClient.shared.complete(system: system, user: user, maxTokens: 80) else {
            return nil
        }
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        guard !cleaned.isEmpty else { return nil }
        return Bridge(sentence: cleaned, prompt: user, response: raw)
    }

    // MARK: - Helpers

    private static func normalizeTag(_ tag: String) -> String {
        tag.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "-")
    }

    /// Pull the first `{ … }` object out of a model response, tolerating code
    /// fences or stray prose around it.
    private static func extractJSON(_ raw: String) -> String? {
        guard let start = raw.firstIndex(of: "{"), let end = raw.lastIndex(of: "}"), start < end else {
            return nil
        }
        return String(raw[start...end])
    }
}
