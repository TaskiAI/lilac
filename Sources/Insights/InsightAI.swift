import Foundation

/// The single DeepSeek call behind Insights: it reads a summary of the writer's
/// recent journaling (local metrics + entry excerpts + their stated focuses) and
/// returns a structured, non-clinical analysis. Fails gracefully — on any error
/// it returns nil and the engine falls back to a local-only report.
///
/// Carries the raw prompt/response so the engine can write an `AICallLog`.
enum InsightAI {
    struct Analysis {
        let headline: String
        let summary: String
        let moodNote: String
        let themes: [String]
        let strengths: [String]
        let gentleNudges: [String]
        let suggestedFocuses: [String]
        let suggestedPrompt: String
        let prompt: String
        let response: String
    }

    static func analyze(metrics: String, entriesText: String, focuses: [String]) async -> Analysis? {
        let system = """
        You are the insights analyzer for a private journaling app called Lilac. \
        You read a summary of someone's recent journaling and reflect patterns \
        back to them. Respond ONLY with JSON, no prose or code fences:
        {
          "headline": "one warm sentence, the single biggest takeaway",
          "summary": "2-3 sentences describing patterns you notice, in second person",
          "mood_note": "one factual sentence about their mood/energy trend, or empty",
          "themes": ["lowercase-hyphenated recurring topics, 2-5"],
          "strengths": ["1-3 things going well, short phrases"],
          "gentle_nudges": ["1-3 soft, non-prescriptive suggestions, short phrases"],
          "suggested_focuses": ["1-3 short focus areas, Title Case, e.g. Reduce anxiety"],
          "suggested_prompt": "one tailored journaling prompt, a single question"
        }
        Rules: Be warm, specific, and descriptive — never diagnose, label, or use \
        clinical language. Base everything ONLY on the provided data; do not invent \
        events. If the data suggests acute crisis or self-harm, keep the tone caring, \
        gently encourage reaching out to someone trusted or a crisis line, and set \
        conservative, supportive nudges. Never quote entries verbatim.
        """

        var user = "METRICS:\n\(metrics)\n"
        if !focuses.isEmpty {
            user += "\nTHEIR CURRENT FOCUS: \(focuses.joined(separator: ", "))\n"
        }
        if !entriesText.isEmpty {
            user += "\nRECENT ENTRY EXCERPTS (paraphrase, don't quote):\n\(entriesText)"
        }

        guard let raw = try? await DeepSeekClient.shared.complete(system: system, user: user, maxTokens: 700),
              let json = extractJSON(raw),
              let obj = try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any] else {
            return nil
        }

        return Analysis(
            headline: string(obj["headline"]),
            summary: string(obj["summary"]),
            moodNote: string(obj["mood_note"]),
            themes: strings(obj["themes"]),
            strengths: strings(obj["strengths"]),
            gentleNudges: strings(obj["gentle_nudges"]),
            suggestedFocuses: strings(obj["suggested_focuses"]),
            suggestedPrompt: string(obj["suggested_prompt"]),
            prompt: user,
            response: raw
        )
    }

    // MARK: Parsing helpers

    private static func string(_ value: Any?) -> String {
        (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private static func strings(_ value: Any?) -> [String] {
        (value as? [String])?
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? []
    }

    private static func extractJSON(_ raw: String) -> String? {
        guard let start = raw.firstIndex(of: "{"), let end = raw.lastIndex(of: "}"), start < end else {
            return nil
        }
        return String(raw[start...end])
    }
}
