import UIKit

extension UIImage {
    /// Downscaled + JPEG-encoded for compact persistence inside a `JournalEntry`.
    /// Photos come off the camera/library at many megapixels; a journal page
    /// never needs that, so we cap the long edge and compress before storing.
    func journalEncoded(maxDimension: CGFloat = 1600, quality: CGFloat = 0.8) -> Data? {
        let longEdge = max(size.width, size.height)
        let scale = longEdge > maxDimension ? maxDimension / longEdge : 1
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let rendered = UIGraphicsImageRenderer(size: target).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
        return rendered.jpegData(compressionQuality: quality)
    }
}
