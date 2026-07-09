import Foundation
import SwiftData

@Model
final class JournalEntry {
    var createdAt: Date
    var prompt: String
    /// Serialized PKDrawing (`PKDrawing.dataRepresentation()`).
    var drawingData: Data

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

    /// The recorded voice notes of an Audio entry, JSON-encoded. Read/written
    /// through `audioClips`; nil for every other format.
    private var audioClipsData: Data?

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
    }
}
