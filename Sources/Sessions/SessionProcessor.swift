import Foundation
import SwiftData

/// Turns a freshly recorded session into a diarized transcript + summary. Tries
/// cloud diarization first (accurate speaker labels); falls back to the
/// on-device recognizer as a flat, unlabeled transcript when no diarization key
/// is configured or the call fails. Runs on the main actor because it writes
/// back into SwiftData.
@MainActor
final class SessionProcessor {
    /// Sessions currently being processed, so a record-view kick and a detail
    /// screen appearing don't diarize the same session twice. Safe as plain
    /// static state because every access is main-actor isolated.
    private static var inFlight: Set<PersistentIdentifier> = []

    private let context: ModelContext
    private let diarizer: DiarizationClient
    private let ai: SessionAI

    init(
        context: ModelContext,
        diarizer: DiarizationClient = .shared,
        ai: SessionAI = SessionAI()
    ) {
        self.context = context
        self.diarizer = diarizer
        self.ai = ai
    }

    /// Resume any sessions still mid-transcription (e.g. the app was closed while
    /// one was processing). Called on launch.
    func runPending() async {
        guard let sessions = try? context.fetch(FetchDescriptor<TherapySession>()) else { return }
        for session in sessions where session.state == .transcribing {
            await process(session)
        }
    }

    /// Process a specific session if it's still awaiting a transcript; a no-op
    /// otherwise. Called when the detail screen appears.
    func processIfNeeded(_ session: TherapySession) async {
        guard session.state == .transcribing else { return }
        await process(session)
    }

    /// Transcribe (diarize when possible) then summarize, updating `session`.
    func process(_ session: TherapySession) async {
        let id = session.persistentModelID
        guard !Self.inFlight.contains(id) else { return }
        Self.inFlight.insert(id)
        defer { Self.inFlight.remove(id) }

        guard let filename = session.audioFilename, SessionAudioStore.exists(filename) else {
            session.state = .failed
            return
        }
        let url = SessionAudioStore.url(for: filename)

        // 1. Transcript — cloud diarization, else the on-device recognizer.
        if diarizer.isConfigured,
           let segments = try? await diarizer.diarize(audioURL: url), !segments.isEmpty {
            session.segments = segments
            session.transcript = segments
                .map { "\($0.speaker): \($0.text)" }
                .joined(separator: "\n")
        } else if await SpeechTranscriber.requestPermission(),
                  let flat = try? await SpeechTranscriber.transcribe(url: url), !flat.isEmpty {
            session.transcript = flat
            session.segments = []
        } else {
            session.state = .failed
            return
        }

        // 2. Summary (best-effort; a missing summary doesn't fail the session).
        if let summary = await ai.summarize(transcript: session.transcript ?? "") {
            session.summary = summary
        }
        session.aiProcessedAt = .now
        session.state = .ready
    }

    /// Force a fresh transcript + summary (used by the detail screen's retry).
    func reprocess(_ session: TherapySession) async {
        session.state = .transcribing
        await process(session)
    }
}
