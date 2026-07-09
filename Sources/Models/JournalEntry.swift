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

    var style: JournalStyle {
        get { styleRawValue.flatMap(JournalStyle.init(rawValue:)) ?? .freeFlow }
        set { styleRawValue = newValue.rawValue }
    }

    var sessionLength: SessionLength {
        get { sessionLengthRawValue.flatMap(SessionLength.init(rawValue:)) ?? .quick }
        set { sessionLengthRawValue = newValue.rawValue }
    }

    init(
        createdAt: Date = .now,
        prompt: String,
        drawingData: Data = Data(),
        style: JournalStyle = .freeFlow,
        sessionLength: SessionLength = .quick
    ) {
        self.createdAt = createdAt
        self.prompt = prompt
        self.drawingData = drawingData
        self.styleRawValue = style.rawValue
        self.sessionLengthRawValue = sessionLength.rawValue
    }
}
