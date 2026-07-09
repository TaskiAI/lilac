import UIKit

/// A faint dot grid drawn *inside* a diagram canvas's scroll content, behind the
/// ink — a light lattice to align boxes and nodes against. This is the diagram
/// counterpart to `RuledBackgroundView`'s ruled lines for the writing page:
/// non-interactive, and it scrolls in lockstep with the drawing.
final class GridBackgroundView: UIView {
    var spacing: CGFloat = 28 { didSet { setNeedsDisplay() } }
    var dotColor: UIColor = .gray { didSet { setNeedsDisplay() } }
    var dotRadius: CGFloat = 1.1 { didSet { setNeedsDisplay() } }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
        contentMode = .redraw
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext(), spacing > 0 else { return }
        ctx.setFillColor(dotColor.cgColor)

        // Only paint the dirty rect's rows/columns so a tall canvas stays cheap.
        let startX = max(spacing, (rect.minX / spacing).rounded(.down) * spacing)
        let startY = max(spacing, (rect.minY / spacing).rounded(.down) * spacing)

        var y = startY
        while y < bounds.height, y <= rect.maxY {
            var x = startX
            while x < bounds.width, x <= rect.maxX {
                ctx.fillEllipse(in: CGRect(x: x - dotRadius, y: y - dotRadius,
                                           width: dotRadius * 2, height: dotRadius * 2))
                x += spacing
            }
            y += spacing
        }
    }
}
