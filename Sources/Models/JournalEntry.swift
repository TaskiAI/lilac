import Foundation
import SwiftData

@Model
final class JournalEntry {
    // Property-level defaults on the non-optional fields so the model is
    // CloudKit-compatible (private iCloud mirroring requires every attribute to
    // be optional or defaulted). `init` still sets them; the defaults only feed
    // schema generation and CloudKit record materialization.
    var createdAt: Date = Date.now
    var prompt: String = ""
    /// Serialized PKDrawing (`PKDrawing.dataRepresentation()`).
    var drawingData: Data = Data()

    // Persisted as optional raw strings so that stores created before these
    // fields existed migrate cleanly: SwiftData's automatic lightweight
    // migration cannot backfill a non-optional custom-enum column on existing
    // rows (it hits a dynamic-cast failure on read), but a missing optional
    // just reads back as nil. The enum API is exposed via the computed
    // properties below; callers still use `entry.style` / `entry.sessionLength`.
    private var styleRawValue: String?
    private var sessionLengthRawValue: String?
    /// The non-writing format (drawing, diagram, …); nil for the prompted
    /// writing entries. Optional for the same clean-migration reason as above.
    private var formatRawValue: String?

    /// A single photo laid *behind* the ink of a drawing/diagram entry, so the
    /// writer can annotate over it. Downscaled JPEG (see `UIImage.journalEncoded`).
    var backgroundImageData: Data?

    /// The placed photos of a Picture (collage) entry, JSON-encoded. Optional
    /// and read/written through `collageItems`; nil for every other format.
    private var collageData: Data?

    /// Typed body text — the transcription plus anything written afterward in an
    /// Audio entry. Optional so pre-existing rows migrate cleanly.
    var text: String?

    /// An optional user-given title for the entry. nil ⇒ untitled; lists fall
    /// back to the prompt/transcript. Migration-safe optional.
    var title: String? = nil

    /// The recorded voice notes of an Audio entry, JSON-encoded. Read/written
    /// through `audioClips`; nil for every other format.
    private var audioClipsData: Data?

    /// The structured check-in of a Log entry, JSON-encoded. Read/written through
    /// `moodLog`; nil for every other format.
    private var logData: Data?

    // MARK: Handwriting transcript (on-device recognition, persisted)

    /// The recognized text of this entry's handwriting (Google ML Kit / Apple
    /// Vision, on-device), persisted so the writer can read it and every AI tool
    /// can use it without re-recognizing. nil until transcribed; "" when nothing
    /// legible was found.
    var transcript: String? = nil
    /// When the transcript was generated.
    var transcriptGeneratedAt: Date? = nil
    /// The `drawingData` byte length captured at transcription time — a cheap
    /// staleness signature. When the current length differs, the ink changed and
    /// the transcript is regenerated.
    var transcriptByteCount: Int? = nil

    // MARK: Rewind metadata (all optional/relationship — migration-safe)

    /// Theme tags for the Rewind feature, JSON-encoded; read/written via `themeTags`.
    private var themeTagsData: Data? = nil
    /// Coarse emotional salience 1…5 from the DeepSeek tagging call; nil until classified.
    var salience: Double? = nil
    /// Crisis/self-harm screening result; nil = not yet classified. Crisis-flagged
    /// entries are never surfaced passively.
    var crisisFlagged: Bool? = nil
    /// When the tagging + safety classification last ran (skip re-classifying).
    var classifiedAt: Date? = nil
    /// For a reflection written against a rewound entry: the source entry it responds to.
    var linkedEntry: JournalEntry? = nil

    // Inverse relationships. CloudKit mirroring requires every relationship to
    // have an inverse; these are the inverses of `linkedEntry`,
    // `RewindCandidate.entry`, and `RewindSession.entry`. All optional/to-many,
    // so migration-safe and rarely read directly.
    /// Entries whose `linkedEntry` points at this one (reflections written against it).
    @Relationship(inverse: \JournalEntry.linkedEntry) var reflections: [JournalEntry]? = nil
    /// Rewind candidates computed from this entry.
    @Relationship(inverse: \RewindCandidate.entry) var rewindCandidates: [RewindCandidate]? = nil
    /// Rewind sessions that surfaced this entry.
    @Relationship(inverse: \RewindSession.entry) var rewindSessions: [RewindSession]? = nil

    /// Theme tags, decoded/encoded from `themeTagsData`.
    var themeTags: [String] {
        get { themeTagsData.flatMap { try? JSONDecoder().decode([String].self, from: $0) } ?? [] }
        set { themeTagsData = try? JSONEncoder().encode(newValue) }
    }

    var style: JournalStyle {
        get { styleRawValue.flatMap(JournalStyle.init(rawValue:)) ?? .freeFlow }
        set { styleRawValue = newValue.rawValue }
    }

    var sessionLength: SessionLength {
        get { sessionLengthRawValue.flatMap(SessionLength.init(rawValue:)) ?? .quick }
        set { sessionLengthRawValue = newValue.rawValue }
    }

    /// The journaling format. `nil` means a prompted writing entry (the default);
    /// a value routes the entry to `DrawingJournalView` / `PictureJournalView`
    /// instead of the writing page.
    var format: JournalFormat? {
        get { formatRawValue.flatMap(JournalFormat.init(rawValue:)) }
        set { formatRawValue = newValue?.rawValue }
    }

    /// The placed photos of a Picture entry. Decodes/encodes `collageData`.
    var collageItems: [CollageItem] {
        get { collageData.flatMap { try? JSONDecoder().decode([CollageItem].self, from: $0) } ?? [] }
        set { collageData = try? JSONEncoder().encode(newValue) }
    }

    /// The recorded voice notes of an Audio entry. Decodes/encodes `audioClipsData`.
    var audioClips: [AudioClip] {
        get { audioClipsData.flatMap { try? JSONDecoder().decode([AudioClip].self, from: $0) } ?? [] }
        set { audioClipsData = try? JSONEncoder().encode(newValue) }
    }

    /// The structured check-in of a Log entry. Decodes/encodes `logData`; a fresh
    /// `MoodLog` (with the default habit checklist) when the entry has none yet.
    var moodLog: MoodLog {
        get { logData.flatMap { try? JSONDecoder().decode(MoodLog.self, from: $0) } ?? MoodLog() }
        set { logData = try? JSONEncoder().encode(newValue) }
    }

    init(
        createdAt: Date = .now,
        prompt: String,
        drawingData: Data = Data(),
        style: JournalStyle = .freeFlow,
        sessionLength: SessionLength = .quick,
        format: JournalFormat? = nil,
        backgroundImageData: Data? = nil,
        text: String? = nil
    ) {
        self.createdAt = createdAt
        self.prompt = prompt
        self.drawingData = drawingData
        self.styleRawValue = style.rawValue
        self.sessionLengthRawValue = sessionLength.rawValue
        self.formatRawValue = format?.rawValue
        self.backgroundImageData = backgroundImageData
        self.collageData = nil
        self.text = text
        self.audioClipsData = nil
        self.logData = nil
    }
}
