import Foundation
import SwiftData

/// Generates and stores insight reports. Like `RewindEngine`, this is the local
/// stand-in for a backend job: it gathers the writer's recent journaling,
/// computes local metrics, asks DeepSeek for a structured analysis, and persists
/// an `InsightReport` other features can read. Runs on the main actor because it
/// mutates the SwiftData context.
///
/// Privacy: generating an AI report sends recent entry text off-device, so it is
/// gated on `insightsEnabled` (defaults on) and no-ops into a local-only report
/// when disabled, offline, or DeepSeek isn't configured.
@MainActor
final class InsightEngine {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    nonisolated static let enabledKey = "insights.enabled"

    var isEnabled: Bool {
        UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true
    }

    /// The most recent report, if any.
    func latest() -> InsightReport? {
        var descriptor = FetchDescriptor<InsightReport>(
            sortBy: [SortDescriptor(\.generatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    /// Whether it's worth regenerating: no report yet, or the latest is stale.
    func isStale(maxAgeDays: Int = 3) -> Bool {
        guard let latest = latest() else { return true }
        let age = Date.now.timeIntervalSince(latest.generatedAt)
        return age > Double(maxAgeDays) * 86_400
    }

    /// Build a fresh report over the last `periodDays`. Persists and returns it.
    /// Always succeeds — falls back to a local-only report when AI is unavailable.
    @discardableResult
    func generate(periodDays: Int = 14, focuses: [String] = []) async -> InsightReport {
        let entries = (try? context.fetch(
            FetchDescriptor<JournalEntry>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        )) ?? []

        let metrics = InsightMetrics.compute(entries: entries, periodDays: periodDays)

        let report = InsightReport()
        report.periodDays = periodDays
        report.entryCount = metrics.entryCount
        report.streak = metrics.streak
        report.averageMood = metrics.averageMood
        report.averageEnergy = metrics.averageEnergy

        if isEnabled, DeepSeekClient.shared.isConfigured, metrics.entryCount > 0 {
            let text = await assembleText(from: entries, periodDays: periodDays)
            if let analysis = await InsightAI.analyze(
                metrics: metrics.promptContext(),
                entriesText: text,
                focuses: focuses
            ) {
                apply(analysis, to: report)
                report.aiPowered = true
                context.insert(AICallLog(kind: .insight, prompt: analysis.prompt, response: analysis.response))
            } else {
                applyLocalFallback(metrics, to: report)
            }
        } else {
            applyLocalFallback(metrics, to: report)
        }

        context.insert(report)
        return report
    }

    // MARK: Assembly

    private func apply(_ analysis: InsightAI.Analysis, to report: InsightReport) {
        report.headline = analysis.headline
        report.summary = analysis.summary
        report.moodNote = analysis.moodNote
        report.themes = analysis.themes
        report.strengths = analysis.strengths
        report.gentleNudges = analysis.gentleNudges
        report.suggestedFocuses = analysis.suggestedFocuses
        report.suggestedPrompt = analysis.suggestedPrompt
    }

    /// A useful report even with no AI: describe the metrics plainly.
    private func applyLocalFallback(_ metrics: InsightMetrics, to report: InsightReport) {
        report.aiPowered = false
        if metrics.entryCount == 0 {
            report.headline = "Your insights will grow as you write."
            report.summary = "Add a few entries — including a Daily Log or two — and Lilac will start noticing patterns in your mood, energy, and themes."
            return
        }
        report.headline = "You journaled \(metrics.entryCount) times in the last \(metrics.periodDays) days."
        var summary = "You're keeping a \(metrics.streak)-day streak."
        if !metrics.moodSeries.isEmpty {
            summary += String(format: " Your mood is averaging %.1f out of 5.", metrics.averageMood)
        }
        report.summary = summary
        report.themes = Array(metrics.topFeelings.map { $0.feeling.lowercased() }.prefix(4))
        if let best = metrics.habitRates.first, best.rate >= 0.5 {
            report.strengths = ["Consistent with \(best.name.lowercased())"]
        }
    }

    /// Recent entry text for the AI, bounded so the request stays small. Uses the
    /// same handwriting-aware extraction as Rewind; capped to a handful of the
    /// most recent entries and truncated per entry.
    private func assembleText(from entries: [JournalEntry], periodDays: Int) async -> String {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -periodDays, to: .now) ?? .now
        let recent = entries.filter { $0.createdAt >= start }.prefix(8)

        var blocks: [String] = []
        var budget = 4000
        for entry in recent {
            let text = await entry.classifiableText()
            guard !text.isEmpty else { continue }
            let dated = entry.createdAt.formatted(.dateTime.month().day())
            let snippet = String(text.prefix(400))
            let block = "[\(dated)] \(snippet)"
            budget -= block.count
            if budget < 0 { break }
            blocks.append(block)
        }
        return blocks.joined(separator: "\n\n")
    }
}
