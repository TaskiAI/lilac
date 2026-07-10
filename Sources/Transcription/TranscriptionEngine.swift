import Foundation
import SwiftData

/// Keeps a persisted, on-device transcript on every handwritten writing entry,
/// so the writer can read it and the AI tools (Insights, Rewind, Companion) and
/// Search can use real words instead of re-recognizing ink each time.
///
/// Recognition is on-device (`HandwritingTextExtractor` — ML Kit or Vision). The
/// transcript is only regenerated when the ink actually changes (tracked by a
/// byte-length signature), so launches stay cheap. Runs on the main actor
/// because it mutates the SwiftData context.
@MainActor
final class TranscriptionEngine {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// Transcribe up to `limit` entries whose ink has no fresh transcript. Bounded
    /// so a large backlog is caught up over a few launches rather than all at once.
    func run(limit: Int = 15) async {
        let descriptor = FetchDescriptor<JournalEntry>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        guard let entries = try? context.fetch(descriptor) else { return }
        for entry in entries.filter({ $0.needsTranscription }).prefix(limit) {
            await transcribe(entry)
        }
    }

    /// Recognize one entry's handwriting and store the result. Records the byte
    /// signature even when nothing legible is found, so it isn't retried forever
    /// (until the ink changes).
    @discardableResult
    func transcribe(_ entry: JournalEntry) async -> String {
        let signature = entry.drawingData.count
        let text = await HandwritingTextExtractor.text(from: entry.drawingData)
        entry.transcript = text
        entry.transcriptByteCount = signature
        entry.transcriptGeneratedAt = .now
        return text
    }
}

extension JournalEntry {
    /// Whether this entry has a fresh transcript for its current ink.
    var hasFreshTranscript: Bool {
        transcript != nil && transcriptByteCount == drawingData.count
    }

    /// Writing entries (free diary / prompted — `format == nil`) are the only ones
    /// whose drawing is handwriting worth transcribing; sketches, diagrams, photos,
    /// audio and logs are not. Needs work when there's no fresh transcript.
    var needsTranscription: Bool {
        format == nil && !hasFreshTranscript
    }
}
