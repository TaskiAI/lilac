import SwiftUI

/// The luminous lavender orb in the home header — a soft glowing sphere full of
/// tiny lights resting on a frosted base. Purely ornamental; evokes calm.
struct GlowOrbView: View {
    var size: CGFloat = 96

    var body: some View {
        ZStack {
            // Soft outer aura.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.homeAccent.opacity(0.35), Color.homeAccent.opacity(0)],
                        center: .center,
                        startRadius: 2,
                        endRadius: size * 0.85
                    )
                )
                .frame(width: size * 1.6, height: size * 1.6)

            // The reflected "base" beneath the sphere.
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [Color.homeAccent.opacity(0.35), Color.homeAccent.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size * 0.9, height: size * 0.62)
                .blur(radius: 6)
                .offset(y: size * 0.62)

            // The sphere itself.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.95),
                            Color.homeAccent.opacity(0.85),
                            Color.homeAccentDeep.opacity(0.92)
                        ],
                        center: UnitPoint(x: 0.38, y: 0.32),
                        startRadius: 1,
                        endRadius: size * 0.62
                    )
                )
                .frame(width: size, height: size)
                .overlay(starfield.frame(width: size, height: size))
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.5), lineWidth: 1)
                        .blur(radius: 0.5)
                )
                .shadow(color: Color.homeAccent.opacity(0.45), radius: 16, x: 0, y: 8)
        }
        .frame(width: size * 1.6, height: size * 1.9)
        .accessibilityHidden(true)
    }

    /// The scattered inner "lights" — deterministic so the orb never flickers on
    /// redraw. Clipped to the sphere.
    private var starfield: some View {
        Canvas { context, canvasSize in
            var seed: UInt64 = 0x9E3779B97F4A7C15
            func next() -> Double {
                seed ^= seed << 13
                seed ^= seed >> 7
                seed ^= seed << 17
                return Double(seed % 10_000) / 10_000
            }
            let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            let maxR = canvasSize.width / 2
            for _ in 0..<48 {
                let angle = next() * 2 * .pi
                let radius = maxR * sqrt(next()) * 0.88
                let point = CGPoint(
                    x: center.x + cos(angle) * radius,
                    y: center.y + sin(angle) * radius
                )
                let dotSize = 0.8 + next() * 1.8
                let rect = CGRect(x: point.x, y: point.y, width: dotSize, height: dotSize)
                context.fill(
                    Path(ellipseIn: rect),
                    with: .color(.white.opacity(0.55 + next() * 0.45))
                )
            }
        }
        .clipShape(Circle())
    }
}

#Preview {
    GlowOrbView()
        .padding(40)
        .background(Color.homeBackgroundBottom)
}
