import CoreGraphics
import Foundation

/// One placed photo in a Picture (collage) journal: its image plus where it sits
/// on the page. Position and size are normalized to the page (0…1) so a collage
/// composed on one device lays out proportionally the same on another.
///
/// The full list is persisted as a JSON-encoded array in
/// `JournalEntry.collageData` — the image bytes travel inside the item.
struct CollageItem: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    /// Downscaled JPEG bytes (see `UIImage.journalEncoded`).
    var imageData: Data
    /// Center as a fraction of the page — x, y in 0…1.
    var centerX: CGFloat = 0.5
    var centerY: CGFloat = 0.4
    /// Displayed width as a fraction of the page width (0…1).
    var widthFraction: CGFloat = 0.6
}
