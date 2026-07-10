import Foundation

/// Weaves the writer's Insights and focus areas into gentle steers — a single
/// optional line, and a short list of prompts to help them get unstuck. Design
/// principle: the AI never writes or thinks for the writer. It offers a question
/// or a nudge; the page stays theirs. The curated `PromptBank` is always the
/// backbone, so this works fully offline and never depends on the AI.
enum PromptSuggestions {
    /// One quiet, encouraging line for the home. Prefers a fresh insight nudge,
    /// then a focus reminder, then a calm default. Never prescriptive.
    static func dailyLine(insight: InsightReport?, focuses: [String]) -> String {
        if let insight, insight.aiPowered, let nudge = insight.gentleNudges.first,
           !nudge.isEmpty {
            return nudge
        }
        if let focus = focuses.first, !focus.isEmpty {
            return "A small step toward \(focus.lowercased()), if you're up for it."
        }
        return "Take a moment for yourself today."
    }

    /// A short menu of optional prompts to begin from — the writer's own
    /// reflected-back prompt first (if there's a fresh one), then a couple leaning
    /// toward their focus, then a varied curated spread. Deduped, capped small.
    static func list(
        insight: InsightReport?,
        focuses: [String],
        date: Date = .now,
        limit: Int = 5
    ) -> [RecommendedPrompt] {
        var out: [RecommendedPrompt] = []
        var seenText = Set<String>()

        func add(_ prompt: RecommendedPrompt) {
            let key = prompt.text.lowercased()
            guard !prompt.text.isEmpty, !seenText.contains(key) else { return }
            seenText.insert(key)
            out.append(prompt)
        }

        // 1. Their own reflection, surfaced back (only when genuinely AI-derived).
        if let insight, insight.aiPowered, !insight.suggestedPrompt.isEmpty {
            add(RecommendedPrompt(text: insight.suggestedPrompt, style: .freeFlow, source: .reflection))
        }

        // 2. Focus-aligned curated prompts (deterministic per day, so steady).
        let dayIndex = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 0
        for focus in focuses.prefix(2) {
            let style = style(for: focus)
            let pool = PromptBank.prompts(for: style)
            guard !pool.isEmpty else { continue }
            add(RecommendedPrompt(text: pool[dayIndex % pool.count], style: style, source: .focus(focus)))
        }

        // 3. Fill out with the varied curated spread.
        for base in RecommendedPrompts.today(date) where out.count < limit {
            add(base)
        }

        return Array(out.prefix(limit))
    }

    /// The prompt to seed a fresh free-flow daily entry with. Prefers the
    /// writer's own reflection when one is fresh (so "start daily" gently picks up
    /// where their patterns point); otherwise a focus-aligned or plain curated
    /// prompt. This seeds a *question*, not content.
    static func seed(for style: JournalStyle, insight: InsightReport?, focuses: [String]) -> String {
        if style == .freeFlow, let insight, insight.aiPowered, !insight.suggestedPrompt.isEmpty {
            return insight.suggestedPrompt
        }
        if style == .freeFlow, let focus = focuses.first {
            return PromptBank.random(for: self.style(for: focus))
        }
        return PromptBank.random(for: style)
    }

    /// Map a free-text focus area to the journaling style whose prompts best
    /// serve it. Purely local heuristic — no AI, no network.
    static func style(for focus: String) -> JournalStyle {
        let lower = focus.lowercased()
        switch true {
        case lower.contains("grat"), lower.contains("thank"), lower.contains("appreciat"):
            return .gratitude
        case lower.contains("anx"), lower.contains("stress"), lower.contains("calm"),
             lower.contains("overwhelm"), lower.contains("emotion"), lower.contains("feel"):
            return .emotional
        case lower.contains("goal"), lower.contains("habit"), lower.contains("pattern"),
             lower.contains("reflect"), lower.contains("review"), lower.contains("clar"):
            return .replayAnalysis
        default:
            return .freeFlow
        }
    }
}
