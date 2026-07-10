import Foundation
import SwiftData

/// A generated insight report over a recent window of journaling. The narrative
/// fields (`headline`/`summary`/…) come from DeepSeek; the metric fields are
/// computed locally. Persisted so the app reads the latest without re-calling
/// the model, and so other features — prompts, the companion, focus suggestions
/// — can consume it. Fresh rows, so non-optional defaults are safe.
@Model
final class InsightReport {
    var generatedAt: Date = Date.now
    var periodDays: Int = 14

    /// True when the AI narrative populated; false for a local-only fallback
    /// report (offline / no key / AI error).
    var aiPowered: Bool = false

    // AI narrative
    var headline: String = ""
    var summary: String = ""
    var moodNote: String = ""
    var suggestedPrompt: String = ""
    private var themesData: Data?
    private var strengthsData: Data?
    private var nudgesData: Data?
    private var focusesData: Data?

    // Local metric snapshot (also shown on the dashboard)
    var entryCount: Int = 0
    var averageMood: Double = 0
    var averageEnergy: Double = 0
    var streak: Int = 0

    var themes: [String] {
        get { decode(themesData) }
        set { themesData = encode(newValue) }
    }
    var strengths: [String] {
        get { decode(strengthsData) }
        set { strengthsData = encode(newValue) }
    }
    var gentleNudges: [String] {
        get { decode(nudgesData) }
        set { nudgesData = encode(newValue) }
    }
    var suggestedFocuses: [String] {
        get { decode(focusesData) }
        set { focusesData = encode(newValue) }
    }

    init() {}

    private func decode(_ data: Data?) -> [String] {
        data.flatMap { try? JSONDecoder().decode([String].self, from: $0) } ?? []
    }
    private func encode(_ value: [String]) -> Data? {
        try? JSONEncoder().encode(value)
    }
}
