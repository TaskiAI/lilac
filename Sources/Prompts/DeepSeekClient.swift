import Foundation

/// A tiny shared client for DeepSeek's OpenAI-compatible Chat Completions API.
/// Both the prompt engine and the Rewind AI calls go through this so the request
/// plumbing and key resolution live in one place.
///
/// The key is read from `DEEPSEEK_API_KEY` (process environment first, then the
/// Info.plist value wired through `project.yml`); no key ⇒ `isConfigured == false`
/// and callers fall back to their offline behavior.
struct DeepSeekClient {
    static let shared = DeepSeekClient()

    let apiKey: String?
    private let session: URLSession
    private let model = "deepseek-chat"
    private let endpoint = URL(string: "https://api.deepseek.com/chat/completions")!

    init(apiKey: String? = DeepSeekClient.resolveAPIKey(), session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    var isConfigured: Bool { apiKey?.isEmpty == false }

    enum ClientError: Error { case notConfigured, badResponse, empty }

    /// One non-streaming completion. Throws on any failure so callers can decide
    /// their own fallback.
    func complete(system: String, user: String, maxTokens: Int = 256) async throws -> String {
        guard let apiKey, !apiKey.isEmpty else { throw ClientError.notConfigured }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 20

        let body = ChatRequest(
            model: model,
            maxTokens: maxTokens,
            messages: [
                .init(role: "system", content: system),
                .init(role: "user", content: user),
            ]
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ClientError.badResponse
        }

        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        let text = decoded.choices.first?.message.content?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let text, !text.isEmpty else { throw ClientError.empty }
        return text
    }

    static func resolveAPIKey() -> String? {
        if let env = ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"], !env.isEmpty {
            return env
        }
        if let plist = Bundle.main.object(forInfoDictionaryKey: "DEEPSEEK_API_KEY") as? String,
           !plist.isEmpty, plist != "$(DEEPSEEK_API_KEY)" {
            return plist
        }
        return nil
    }
}

// MARK: - Wire types (DeepSeek / OpenAI-compatible)

private struct ChatRequest: Encodable {
    let model: String
    let maxTokens: Int
    let messages: [Message]

    enum CodingKeys: String, CodingKey {
        case model, messages
        case maxTokens = "max_tokens"
    }

    struct Message: Encodable {
        let role: String
        let content: String
    }
}

private struct ChatResponse: Decodable {
    let choices: [Choice]
    struct Choice: Decodable { let message: Message }
    struct Message: Decodable { let content: String? }
}
