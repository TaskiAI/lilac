import SwiftUI

/// Faint horizontal rules for handwriting, with a soft left margin.
/// `spacing` is the gap between lines; the journal's spacing slider drives it.
struct RuledPaper: View {
    var spacing: CGFloat
    var rule: Color = .rule
    var margin: Color = .margin
    var topInset: CGFloat = 12
    var marginX: CGFloat = 32

    var body: some View {
        Canvas { context, size in
            var y = topInset + spacing
            while y < size.height {
                var line = Path()
                line.move(to: CGPoint(x: 0, y: y))
                line.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(line, with: .color(rule), lineWidth: 0.75)
                y += spacing
            }

            var marginLine = Path()
            marginLine.move(to: CGPoint(x: marginX, y: 0))
            marginLine.addLine(to: CGPoint(x: marginX, y: size.height))
            context.stroke(marginLine, with: .color(margin.opacity(0.35)), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}
