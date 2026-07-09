import SwiftUI

/// Visual identity for a journaling surface. Each journaling type (free diary,
/// a prompted reflection, a gratitude log, …) can carry its own theme; `.diary`
/// is the warm, aged-paper default the whole app is built around.
struct JournalTheme {
    var paper: Color
    var ink: Color
    var rule: Color
    var margin: Color
    /// How tight/loose the ruled lines can go, and where the slider starts.
    var spacingRange: ClosedRange<CGFloat>
    var defaultSpacing: CGFloat

    static let diary = JournalTheme(
        paper: .paper,
        ink: .ink,
        rule: .rule,
        margin: .margin,
        spacingRange: 26...64,
        defaultSpacing: 40
    )
}
