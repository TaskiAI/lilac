import Foundation

/// The AI companion's brain: a warm, non-clinical listener that reflects the
/// writer's words back to them. It sends the recent conversation (plus a light
/// summary of recent journaling, if available) to DeepSeek, and falls back to a
/// gentle canned reflection on any failure — so the companion always replies.
///
/// Like the rest of Lilac's AI, this sends text off-device; it is only reached
/// from the AI-companion screen, which the writer opens deliberately.
struct CompanionEngine {
    var client = DeepSeekClient.shared

    private static let systemPrompt = """
    You are a warm, grounded journaling companion inside a private diary app \
    called Lilac. You listen and gently reflect the writer's own words back to \
    them. You are NOT a therapist and never diagnose, label, or give clinical \
    advice. Keep replies short (1-3 sentences), curious, and kind. Ask at most \
    one soft, open question. Mirror the writer's tone. Never be preachy or \
    prescriptive. If the writer expresses acute crisis or thoughts of self-harm, \
    gently encourage them to reach out to someone they trust or a local crisis \
    line, and do not attempt to counsel further.
    """

    /// Produce the companion's next reply given the running transcript. `context`
    /// is an optional short note about recent entries to ground the reply.
    func reply(to history: [CompanionTurn], context: String?) async -> String {
        var turns: [ChatTurn] = [ChatTurn(role: "system", content: Self.systemPrompt)]
        if let context, !context.isEmpty {
            turns.append(ChatTurn(
                role: "system",
                content: "Light context on the writer's recent journaling (do not quote verbatim): \(context)"
            ))
        }
        turns += history.map { ChatTurn(role: $0.role.rawValue, content: $0.text) }

        if let reply = try? await client.chat(messages: turns, maxTokens: 300) {
            return reply
        }
        return Self.offlineReflection(for: history.last?.text ?? "")
    }

    /// A gentle, content-free reflection used when DeepSeek isn't reachable, so
    /// the companion still responds instead of erroring. Computed once, when the
    /// assistant message is created, so a random pick is fine.
    static func offlineReflection(for lastUserText: String) -> String {
        let openers = [
            "Thank you for putting that into words. What feels most alive in it for you right now?",
            "I hear you. If you sat with that a moment longer, what would you add?",
            "That sounds like it matters. What's underneath it, do you think?",
            "I'm here with you. What would you like to hold onto from this?",
            "It takes something to name that. Where do you notice it in your body?"
        ]
        return openers.randomElement() ?? openers[0]
    }
}

/// A companion turn decoupled from SwiftData, so the engine stays Foundation-only.
struct CompanionTurn {
    let role: CompanionRole
    let text: String
}
