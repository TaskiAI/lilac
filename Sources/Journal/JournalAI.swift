import Foundation

/// Generates therapy-aware journaling prompts grounded in a recorded session, so
/// the journal reflects on what was actually discussed — the thing a generic
/// journal can't do. Uses the shared DeepSeek client; falls back to curated
/// prompts on any failure, so a prompt is always available (and text only goes
/// off-device when the key is configured).
struct JournalAI {
    var client = DeepSeekClient.shared

    private static let system = """
    You write a single short, warm journaling prompt for someone reflecting \
    between therapy sessions. Ground it in what they worked on in their last \
    session (provided). One or two sentences, second person, gently inviting them \
    to notice how it has shown up in daily life. Non-clinical, never diagnostic. \
    Return ONLY the prompt text — no preamble, no quotation marks.
    """

    /// A reflection prompt grounded in the session's summary (or transcript).
    /// Falls back to a curated generic prompt if the model isn't reachable.
    func reflectionPrompt(for session: TherapySession) async -> String {
        let grounding = (session.summary?.isEmpty == false ? session.summary : session.transcript) ?? ""
        let trimmed = grounding.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return Self.genericPrompt() }

        if let prompt = try? await client.complete(
            system: Self.system,
            user: "Last session:\n\(String(trimmed.prefix(6000)))",
            maxTokens: 120
        ) {
            return prompt
        }
        return Self.genericPrompt()
    }

    /// A generic (non-grounded) reflection prompt, for a blank entry with no session.
    static func genericPrompt() -> String { generic.randomElement() ?? generic[0] }

    private static let generic = [
        "What's been sitting with you since your last session?",
        "Where did something you're working on show up this week?",
        "What felt different this week, even a little?",
        "What would you want to bring to your next session?",
        "What were you kinder to yourself about this week — and where was it harder?",
    ]
}
