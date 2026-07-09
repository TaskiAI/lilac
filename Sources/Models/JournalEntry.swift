import Foundation
import SwiftData

@Model
final class JournalEntry {
    var createdAt: Date
    var prompt: String
    /// Serialized PKDrawing (`PKDrawing.dataRepresentation()`).
    var drawingData: Data

    init(createdAt: Date = .now, prompt: String, drawingData: Data = Data()) {
        self.createdAt = createdAt
        self.prompt = prompt
        self.drawingData = drawingData
    }
}
