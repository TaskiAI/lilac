import Speech

/// Turns a recorded audio file into text with the Speech framework, preferring
/// on-device recognition (private, no network) when the device supports it.
/// Callers treat any failure as "keep the audio, skip the text."
enum SpeechTranscriber {
    enum TranscriptionError: Error { case unavailable }

    /// Ask for speech-recognition authorization.
    static func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    /// Transcribe the file at `url`, returning the best full transcription.
    static func transcribe(url: URL) async throws -> String {
        guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else {
            throw TranscriptionError.unavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        // A recognition task can call back more than once; resume the
        // continuation exactly once.
        let box = ResumeGuard()
        return try await withCheckedThrowingContinuation { continuation in
            recognizer.recognitionTask(with: request) { result, error in
                if box.done { return }
                if let error {
                    box.done = true
                    continuation.resume(throwing: error)
                } else if let result, result.isFinal {
                    box.done = true
                    continuation.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }
    }

    private final class ResumeGuard {
        var done = false
    }
}
