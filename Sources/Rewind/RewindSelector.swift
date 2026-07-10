import Foundation

/// The single authoritative gate that decides whether — and which — candidate is
/// surfaced. Every guardrail lives here, in one pure function, never in the UI:
///
/// - `frequency == off`  → nothing is ever selected.
/// - `enabled == false`  → nothing is ever selected.
/// - not enough time since the last rewind → nothing yet.
/// - `crisisFlagged` candidates are excluded from passive surfacing.
/// - candidates whose theme tags intersect the muted set are excluded.
/// - candidates shown within the last 30 days are excluded.
///
/// It is Foundation-only and side-effect-free so the guardrails can be unit
/// tested without SwiftData, the network, or the UI.
enum RewindSelector {
    static let recencyExclusionDays = 30

    struct Candidate {
        var salienceScore: Double
        var themeTags: [String]
        var crisisFlagged: Bool
        var lastSurfaced: Date?
    }

    struct Settings {
        var enabled: Bool
        var frequency: RewindFrequency
        var mutedThemes: [String]
        var lastRewindAt: Date?
    }

    /// Returns the index of the chosen candidate in `candidates`, or `nil` when
    /// no rewind should surface.
    static func select(
        from candidates: [Candidate],
        settings: Settings,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Int? {
        // Respect "off" and the master switch completely.
        guard settings.enabled, let intervalDays = settings.frequency.intervalDays else { return nil }

        // Frequency gate: enough time since the last surfaced rewind?
        if let last = settings.lastRewindAt {
            let daysSince = calendar.dateComponents([.day], from: last, to: now).day ?? .max
            if daysSince < intervalDays { return nil }
        }

        let muted = Set(settings.mutedThemes)

        let eligible = candidates.enumerated().filter { _, candidate in
            if candidate.crisisFlagged { return false }
            if !muted.isDisjoint(with: Set(candidate.themeTags)) { return false }
            if let shown = candidate.lastSurfaced {
                let daysSinceShown = calendar.dateComponents([.day], from: shown, to: now).day ?? .max
                if daysSinceShown < recencyExclusionDays { return false }
            }
            return true
        }

        return eligible.max { $0.element.salienceScore < $1.element.salienceScore }?.offset
    }
}
