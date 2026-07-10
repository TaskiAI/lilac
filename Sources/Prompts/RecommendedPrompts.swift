import Foundation

/// Where a suggested prompt came from, so the UI can label it honestly and
/// gently. The point is to steer, not to write for the user.
enum PromptSource: Hashable {
    /// A varied prompt from the curated bank — the default, always-available.
    case curated
    /// Chosen because it leans toward one of the writer's focus areas.
    case focus(String)
    /// Surfaced from the writer's own recent reflections (an insight).
    case reflection

    /// A short, quiet label. `nil` for curated (no label needed).
    var label: String? {
        switch self {
        case .curated: return nil
        case .focus(let area): return "Toward \(area.lowercased())"
        case .reflection: return "From your reflections"
        }
    }

    var icon: String {
        switch self {
        case .curated: return "text.quote"
        case .focus: return "scope"
        case .reflection: return "sparkles"
        }
    }
}

/// One suggested prompt for the daily-journal reminder, tagged with the style
/// it belongs to so the entry it starts carries the right badge and pool, and
/// with its `source` so the UI can hint (quietly) where it came from.
struct RecommendedPrompt: Identifiable, Hashable {
    let text: String
    let style: JournalStyle
    var source: PromptSource = .curated

    var id: String { "\(style.rawValue)|\(text)" }
}

/// Source of the "recommended prompts" shown on the home screen's daily-journal
/// reminder. Today it curates a small spread across styles from `PromptBank`,
/// stable within a given day so the dropdown doesn't reshuffle on every redraw.
///
/// This is the seam for the roadmap: later these recommendations come from
/// therapy sessions and other AI analyzers. The homepage depends only on
/// `today(...)`, so that swap stays local to this file.
enum RecommendedPrompts {
    /// A varied spread — one prompt per style — chosen deterministically from the
    /// day of the year, so the list is steady through a day and rotates over time.
    static func today(_ date: Date = .now, calendar: Calendar = .current) -> [RecommendedPrompt] {
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 0
        return JournalStyle.allCases.compactMap { style in
            let pool = PromptBank.prompts(for: style)
            guard !pool.isEmpty else { return nil }
            let text = pool[dayOfYear % pool.count]
            return RecommendedPrompt(text: text, style: style)
        }
    }
}
