import SwiftUI

extension Color {
    /// Lilac's signature accent. Calm, soft purple.
    static let lilac = Color(red: 0.63, green: 0.51, blue: 0.83)
    static let lilacSoft = Color(red: 0.95, green: 0.93, blue: 0.98)

    // MARK: - Diary palette (warm, aged paper)

    /// Warm ivory — the page.
    static let paper = Color(red: 0.965, green: 0.937, blue: 0.878)
    /// Warm near-black — the writing.
    static let ink = Color(red: 0.20, green: 0.17, blue: 0.14)
    /// Faint sepia — the ruled lines.
    static let rule = Color(red: 0.80, green: 0.72, blue: 0.57).opacity(0.6)
    /// Dried lilac — the left margin.
    static let margin = Color(red: 0.60, green: 0.49, blue: 0.62)
}
