import Foundation
import SwiftData

/// A therapy session the writer records (or schedules ahead of time). Unlike the
/// short voice notes of an Audio journal entry, a session is a long, two-person
/// conversation, so the audio lives on disk (`SessionAudioStore`) and only its
/// filename is stored here. Once recorded, it is transcribed with speaker labels
/// (cloud diarization, see `DiarizationClient`) and summarized, so the session
/// becomes a recall surface the AI tools can draw on.
///
/// A brand-new `@Model` — remember to register it in `LilacApp`'s container.
@Model
final class TherapySession {
    // Non-optional fields carry property-level defaults so the model is
    // CloudKit-compatible (see `JournalEntry`).
    var createdAt: Date = Date.now
    /// When the session is (or was) held. Future-dated sessions with no recording
    /// yet are the "upcoming" ones shown in the calendar strip.
    var date: Date = Date.now
    var title: String = ""
    var therapistName: String = ""
    /// Free notes to bring or take away (used mainly while a session is scheduled).
    var notes: String = ""

    // MARK: Recording

    /// The recorded audio's filename in `SessionAudioStore` (Application Support).
    /// nil until the session is recorded. NOTE: the audio file lives on disk, not
    /// in the store, so CloudKit backs up the transcript/summary — not the audio.
    var audioFilename: String?
    var duration: TimeInterval = 0

    // MARK: Transcript

    /// The flat transcript text — either "Speaker: line" rows joined from the
    /// diarized segments, or the on-device recognizer's unlabeled text when no
    /// diarization key is configured. nil until transcription runs.
    var transcript: String?
    /// The speaker-tagged utterances from cloud diarization, JSON-encoded; read
    /// and written through `segments`. Empty when only a flat transcript exists.
    private var segmentsData: Data?
    /// Whether to swap which raw speaker maps to "You" vs. the therapist, since
    /// diarization can't know identities. Toggled from the detail screen.
    var swapSpeakers: Bool = false

    // MARK: AI

    /// A concise, non-clinical summary of the session; nil until generated.
    var summary: String?
    /// When the transcript + summary were produced.
    var aiProcessedAt: Date?
    /// Processing lifecycle, stored raw (optional for clean migration). Exposed
    /// through `state`.
    private var stateRawValue: String?
    /// The per-session Q&A thread, JSON-encoded; read/written through `chat`.
    private var chatData: Data?

    var state: SessionState {
        get { stateRawValue.flatMap(SessionState.init(rawValue:)) ?? .scheduled }
        set { stateRawValue = newValue.rawValue }
    }

    /// The diarized utterances. Decodes/encodes `segmentsData`.
    var segments: [SessionSegment] {
        get { segmentsData.flatMap { try? JSONDecoder().decode([SessionSegment].self, from: $0) } ?? [] }
        set { segmentsData = try? JSONEncoder().encode(newValue) }
    }

    /// The per-session Q&A messages. Decodes/encodes `chatData`.
    var chat: [SessionChatMessage] {
        get { chatData.flatMap { try? JSONDecoder().decode([SessionChatMessage].self, from: $0) } ?? [] }
        set { chatData = try? JSONEncoder().encode(newValue) }
    }

    /// Whether the session has been recorded (vs. only scheduled).
    var hasRecording: Bool { audioFilename != nil }

    init(
        date: Date = .now,
        title: String = "",
        therapistName: String = "",
        notes: String = "",
        state: SessionState = .scheduled
    ) {
        self.createdAt = .now
        self.date = date
        self.title = title
        self.therapistName = therapistName
        self.notes = notes
        self.duration = 0
        self.swapSpeakers = false
        self.stateRawValue = state.rawValue
    }
}

/// Where a session is in its lifecycle.
enum SessionState: String {
    /// Booked for the future, no audio yet.
    case scheduled
    /// Audio captured; transcript/summary being produced.
    case transcribing
    /// Transcript + summary ready.
    case ready
    /// Transcription failed (no legible audio / offline with no fallback).
    case failed
}

/// One speaker-tagged utterance from diarization. `speaker` is the raw label the
/// service returns ("A", "B", …); the detail view maps it to You / the therapist.
struct SessionSegment: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var speaker: String
    var text: String
    /// Start / end offsets in seconds from the top of the recording.
    var start: TimeInterval
    var end: TimeInterval
}

/// One message in a session's grounded Q&A thread.
struct SessionChatMessage: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var isUser: Bool
    var text: String
    var createdAt: Date = .now
}
