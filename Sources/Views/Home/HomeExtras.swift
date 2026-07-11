import SwiftUI

extension View {
    /// The standard white card: rounded, hairline-bordered, softly shadowed.
    /// Shared across the Sessions surface.
    func homeCardBackground() -> some View {
        background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.homeCard)
                .shadow(color: Color.homeAccent.opacity(0.10), radius: 12, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.homeHairline.opacity(0.7), lineWidth: 1)
        )
    }
}
