import Foundation

/// The AI tooling over a recorded session's transcript: a concise summary and a
/// grounded Q&A. Both go through the shared DeepSeek client and fall back
/// gracefully so the UI never hard-errors. Like the rest of Lilac's AI, this
/// sends transcript text off-device.
struct SessionAI {
    var client = DeepSeekClient.shared

    private static let summarySystem = """
    You summarize a therapy session transcript for the client's own private \
    records. Be warm, concrete, and non-clinical — you are not a therapist and \
    never diagnose or give clinical advice. In 4-6 short bullet points, capture \
    the main themes discussed, any insight the client reached, and any actions \
    or intentions they named. Use plain, gentle language and the client's own \
    framing where you can.
    """

    private static let qaSystem = """
    You answer questions about a single therapy session using ONLY the transcript \
    provided. Be warm and concise (1-4 sentences). If the transcript doesn't \
    contain the answer, say so plainly rather than inventing detail. You are not a \
    therapist: never diagnose or give clinical advice — reflect what was said.
    """

    /// A short bulleted summary of the session, or nil if unavailable/offline.
    func summarize(transcript: String) async -> String? {
        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        return try? await client.complete(
            system: Self.summarySystem,
            user: "Transcript:\n\(String(text.prefix(12_000)))",
            maxTokens: 500
        )
    }

    /// Answer a question grounded in the transcript, keeping the running thread.
    /// Returns a gentle fallback string on any failure.
    func answer(question: String, transcript: String, history: [SessionChatMessage]) async -> String {
        var turns: [ChatTurn] = [
            ChatTurn(role: "system", content: Self.qaSystem),
            ChatTurn(role: "system", content: "Session transcript:\n\(String(transcript.prefix(12_000)))")
        ]
        turns += history.map { ChatTurn(role: $0.isUser ? "user" : "assistant", content: $0.text) }
        turns.append(ChatTurn(role: "user", content: question))

        if let reply = try? await client.chat(messages: turns, maxTokens: 400) {
            return reply
        }
        return "I couldn't reach the assistant just now — your transcript is saved, so try again in a moment."
    }
}
