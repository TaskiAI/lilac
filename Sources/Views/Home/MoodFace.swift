import SwiftUI

/// A minimal monochrome outline face — circle, two dot eyes, and a mouth that
/// curves from a frown (level 1) through flat (3) to a smile (level 5). Matches
/// the line-drawn mood faces in the home design; scales to any frame.
struct MoodFace: View {
    /// Mood 1…5.
    var level: Int
    var color: Color = .homeAccent
    var lineWidth: CGFloat = 1.6

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let inset = lineWidth

            // Face outline.
            let faceRect = CGRect(x: inset, y: inset, width: w - inset * 2, height: h - inset * 2)
            context.stroke(Path(ellipseIn: faceRect), with: .color(color), lineWidth: lineWidth)

            // Eyes.
            let eyeR = w * 0.055
            let eyeY = h * 0.40
            for eyeX in [w * 0.37, w * 0.63] {
                let dot = CGRect(x: eyeX - eyeR, y: eyeY - eyeR, width: eyeR * 2, height: eyeR * 2)
                context.fill(Path(ellipseIn: dot), with: .color(color))
            }

            // Mouth: control point below the endpoints => smile, above => frown.
            let clamped = CGFloat(max(1, min(5, level)))
            let t = (clamped - 3) / 2                 // -1 (sad) … +1 (happy)
            let mouthY = h * 0.60
            let half = w * 0.18
            let dip = t * (h * 0.15)
            var mouth = Path()
            mouth.move(to: CGPoint(x: w * 0.5 - half, y: mouthY))
            mouth.addQuadCurve(
                to: CGPoint(x: w * 0.5 + half, y: mouthY),
                control: CGPoint(x: w * 0.5, y: mouthY + dip)
            )
            context.stroke(
                mouth,
                with: .color(color),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
        }
        .accessibilityLabel(MoodLog.moodLabel(level))
    }
}

#Preview {
    HStack(spacing: 12) {
        ForEach(1...5, id: \.self) { MoodFace(level: $0).frame(width: 32, height: 32) }
    }
    .padding()
}
