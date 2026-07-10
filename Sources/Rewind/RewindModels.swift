import Foundation
import SwiftData

/// A scored, safety-screened candidate for resurfacing. Computed by
/// `RewindEngine` from an entry's tags/salience; consumed by `RewindSelector`.
/// These are fresh rows (no pre-existing data), so non-optional stored
/// properties and arrays are safe here — unlike `JournalEntry`.
@Model
final class RewindCandidate {
    var entry: JournalEntry?
    /// Weighted score: thematic recurrence + recency balance + emotional salience.
    var salienceScore: Double = 0
    /// Theme tags copied onto the candidate for fast, query-time mute filtering.
    var themeTags: [String] = []
    var lastSurfaced: Date?
    var surfacedCount: Int = 0
    /// Crisis-flagged candidates are excluded from passive surfacing entirely.
    var crisisFlagged: Bool = false
    var computedAt: Date = Date.now

    init(entry: JournalEntry?, salienceScore: Double, themeTags: [String], crisisFlagged: Bool) {
        self.entry = entry
        self.salienceScore = salienceScore
        self.themeTags = themeTags
        self.crisisFlagged = crisisFlagged
    }
}

/// A log row for each time a rewind was shown and what came of it.
@Model
final class RewindSession {
    var entry: JournalEntry?
    var shownAt: Date = Date.now
    /// `RewindOutcome` raw value.
    var outcomeRaw: String = RewindOutcome.opened.rawValue
    /// `RewindMode` raw value.
    var modeRaw: String = RewindMode.theme.rawValue

    var outcome: RewindOutcome {
        get { RewindOutcome(rawValue: outcomeRaw) ?? .opened }
        set { outcomeRaw = newValue.rawValue }
    }

    var mode: RewindMode {
        get { RewindMode(rawValue: modeRaw) ?? .theme }
        set { modeRaw = newValue.rawValue }
    }

    init(entry: JournalEntry?, shownAt: Date = .now, outcome: RewindOutcome, mode: RewindMode) {
        self.entry = entry
        self.shownAt = shownAt
        self.outcomeRaw = outcome.rawValue
        self.modeRaw = mode.rawValue
    }
}

/// The single user-level settings row for the rewind feature.
@Model
final class RewindSettings {
    /// Master switch. Defaults on per product decision, but the whole AI pipeline
    /// (which sends entry text to DeepSeek) is gated on this being true.
    var enabled: Bool = true
    var frequencyRaw: String = RewindFrequency.weekly.rawValue
    var intensityRaw: String = RewindIntensity.light.rawValue
    /// Theme tags the user has opted out of resurfacing. Excluded in the selector.
    var mutedThemes: [String] = []
    var lastRewindAt: Date?

    var frequency: RewindFrequency {
        get { RewindFrequency(rawValue: frequencyRaw) ?? .weekly }
        set { frequencyRaw = newValue.rawValue }
    }

    var intensity: RewindIntensity {
        get { RewindIntensity(rawValue: intensityRaw) ?? .light }
        set { intensityRaw = newValue.rawValue }
    }

    init() {}
}

/// An audit record of a DeepSeek call. Kept because this feature touches
/// sensitive mental-health content; prompts/responses are stored locally only.
@Model
final class AICallLog {
    var timestamp: Date = Date.now
    /// `AICallKind` raw value.
    var kindRaw: String = AICallKind.tagging.rawValue
    var prompt: String = ""
    var response: String = ""

    init(kind: AICallKind, prompt: String, response: String) {
        self.kindRaw = kind.rawValue
        self.prompt = prompt
        self.response = response
    }
}
