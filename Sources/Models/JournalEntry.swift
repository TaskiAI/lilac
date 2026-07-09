import Foundation
import SwiftData

@Model
final class JournalEntry {
    var createdAt: Date
    var prompt: String
    /// Serialized PKDrawing (`PKDrawing.dataRepresentation()`).
    var drawingData: Data
    var style: JournalStyle
    var sessionLength: SessionLength

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
        self.style = style
        self.sessionLength = sessionLength
    }
}
