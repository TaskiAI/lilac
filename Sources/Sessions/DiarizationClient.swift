import Foundation

/// Cloud speaker-diarization via AssemblyAI's REST API: upload the session
/// audio, request a transcript with speaker labels, poll until it's done, and
/// return speaker-tagged utterances.
///
/// Optional, in the same spirit as Lilac's other integrations (ML Kit, Google
/// Sign-In): without an `ASSEMBLYAI_API_KEY` it reports `isConfigured == false`
/// and callers fall back to the on-device recognizer (a flat, unlabeled
/// transcript). The key is read from the process environment first, then the
/// Info.plist value wired through `project.yml`.
///
/// Privacy note: unlike the on-device recognizer, this sends the session AUDIO
/// off-device to AssemblyAI. It is only reached from the Sessions recorder,
/// which the writer starts deliberately, and the record screen says so.
struct DiarizationClient {
    static let shared = DiarizationClient()

    let apiKey: String?
    private let session: URLSession
    private let base = URL(string: "https://api.assemblyai.com/v2")!

    init(apiKey: String? = DiarizationClient.resolveAPIKey(), session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    var isConfigured: Bool { apiKey?.isEmpty == false }

    enum ClientError: Error { case notConfigured, upload, request, failed, timeout }

    /// Diarize the audio file at `audioURL`, returning speaker-tagged segments.
    /// Throws on any failure so the caller can fall back to on-device text.
    func diarize(audioURL: URL) async throws -> [SessionSegment] {
        guard let apiKey, !apiKey.isEmpty else { throw ClientError.notConfigured }
        let audio = try Data(contentsOf: audioURL)
        let uploadURL = try await upload(audio, key: apiKey)
        let id = try await requestTranscript(audioURL: uploadURL, key: apiKey)
        return try await poll(id: id, key: apiKey)
    }

    // MARK: Steps

    private func upload(_ data: Data, key: String) async throws -> String {
        var request = URLRequest(url: base.appendingPathComponent("upload"))
        request.httpMethod = "POST"
        request.setValue(key, forHTTPHeaderField: "authorization")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120

        let (data, response) = try await session.upload(for: request, from: data)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ClientError.upload
        }
        return try JSONDecoder().decode(UploadResponse.self, from: data).upload_url
    }

    private func requestTranscript(audioURL: String, key: String) async throws -> String {
        var request = URLRequest(url: base.appendingPathComponent("transcript"))
        request.httpMethod = "POST"
        request.setValue(key, forHTTPHeaderField: "authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            TranscriptRequest(audio_url: audioURL, speaker_labels: true)
        )

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ClientError.request
        }
        return try JSONDecoder().decode(TranscriptResponse.self, from: data).id
    }

    /// Poll the transcript until it completes (or errors / times out). AssemblyAI
    /// processes roughly in real time, so a long session can take a few minutes;
    /// we poll every 5s up to ~15 minutes.
    private func poll(id: String, key: String) async throws -> [SessionSegment] {
        let url = base.appendingPathComponent("transcript/\(id)")
        for _ in 0..<180 {
            var request = URLRequest(url: url)
            request.setValue(key, forHTTPHeaderField: "authorization")

            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw ClientError.failed
            }
            let decoded = try JSONDecoder().decode(TranscriptResponse.self, from: data)
            switch decoded.status {
            case "completed":
                return (decoded.utterances ?? []).map {
                    SessionSegment(
                        speaker: $0.speaker,
                        text: $0.text,
                        start: Double($0.start) / 1000,
                        end: Double($0.end) / 1000
                    )
                }
            case "error":
                throw ClientError.failed
            default:
                try await Task.sleep(for: .seconds(5))
            }
        }
        throw ClientError.timeout
    }

    static func resolveAPIKey() -> String? {
        if let env = ProcessInfo.processInfo.environment["ASSEMBLYAI_API_KEY"], !env.isEmpty {
            return env
        }
        if let plist = Bundle.main.object(forInfoDictionaryKey: "ASSEMBLYAI_API_KEY") as? String,
           !plist.isEmpty, plist != "$(ASSEMBLYAI_API_KEY)" {
            return plist
        }
        return nil
    }
}

// MARK: - Wire types (AssemblyAI)

private struct UploadResponse: Decodable { let upload_url: String }

private struct TranscriptRequest: Encodable {
    let audio_url: String
    let speaker_labels: Bool
}

private struct TranscriptResponse: Decodable {
    let id: String
    let status: String?
    let utterances: [Utterance]?

    struct Utterance: Decodable {
        let speaker: String
        let text: String
        let start: Int
        let end: Int
    }
}
