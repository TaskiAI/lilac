import UIKit

/// UIKit twin of `RuledPaper`, drawn *inside* the scrolling `PKCanvasView`'s
/// content so the rules scroll in lockstep with the ink. Non-interactive.
final class RuledBackgroundView: UIView {
    var spacing: CGFloat = 34 { didSet { setNeedsDisplay() } }
    var ruleColor: UIColor = .gray { didSet { setNeedsDisplay() } }
    var marginColor: UIColor = .purple { didSet { setNeedsDisplay() } }
    var topInset: CGFloat = 12 { didSet { setNeedsDisplay() } }
    var marginX: CGFloat = 32 { didSet { setNeedsDisplay() } }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
        contentMode = .redraw
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext(), spacing > 0 else { return }

        ctx.setLineWidth(0.75)
        ctx.setStrokeColor(ruleColor.cgColor)
        var y = topInset + spacing
        while y < bounds.height {
            ctx.move(to: CGPoint(x: 0, y: y))
            ctx.addLine(to: CGPoint(x: bounds.width, y: y))
            ctx.strokePath()
            y += spacing
        }

        ctx.setLineWidth(1)
        ctx.setStrokeColor(marginColor.withAlphaComponent(0.35).cgColor)
        ctx.move(to: CGPoint(x: marginX, y: 0))
        ctx.addLine(to: CGPoint(x: marginX, y: bounds.height))
        ctx.strokePath()
    }
}
