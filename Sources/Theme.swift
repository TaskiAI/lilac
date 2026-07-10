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

    // MARK: - Home palette (soft lavender)
    //
    // The home screen wears a lighter, airier lavender than the aged-paper
    // diary. These tokens are scoped to the home surface; the writing page
    // still routes through `JournalTheme`.

    /// Primary lavender — headings, active icons, accents.
    static let homeAccent = Color(red: 0.545, green: 0.478, blue: 0.753)
    /// A deeper lavender for the hero greeting.
    static let homeAccentDeep = Color(red: 0.478, green: 0.408, blue: 0.706)
    /// Muted slate-grey for secondary copy and timestamps.
    static let homeSecondary = Color(red: 0.596, green: 0.584, blue: 0.655)
    /// The faint lavender fill behind the primary CTA cards.
    static let homeTint = Color(red: 0.957, green: 0.945, blue: 0.984)
    /// Very light lavender used for chip / icon-circle fills.
    static let homeHairline = Color(red: 0.878, green: 0.855, blue: 0.945)
    /// Page-background gradient endpoints (top → bottom).
    static let homeBackgroundTop = Color.white
    static let homeBackgroundBottom = Color(red: 0.949, green: 0.937, blue: 0.984)

    // MARK: - Clean writing paper (white page, grey rules)

    /// The writing page — plain white.
    static let cleanPaper = Color.white
    /// Neutral near-black for handwriting + title.
    static let cleanInk = Color(red: 0.15, green: 0.15, blue: 0.17)
    /// Soft grey ruled lines.
    static let cleanRule = Color(red: 0.82, green: 0.82, blue: 0.85)
    /// Grey left margin + spacing slider tint.
    static let cleanMargin = Color(red: 0.72, green: 0.72, blue: 0.77)
}
