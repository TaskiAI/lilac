import Foundation

/// A point in a daily trend series (mood/energy averaged per day).
struct InsightPoint: Identifiable {
    let date: Date
    let value: Double
    var id: Date { date }
}

/// Locally-computed aggregates over a recent window of entries — no AI. Drives
/// the dashboard charts and is also summarized into the DeepSeek prompt so the
/// model reasons over structure, not just raw text.
struct InsightMetrics {
    let periodDays: Int
    let entryCount: Int
    let streak: Int
    let averageMood: Double
    let averageEnergy: Double
    let moodSeries: [InsightPoint]
    let energySeries: [InsightPoint]
    let habitRates: [(name: String, rate: Double)]
    let topFeelings: [(feeling: String, count: Int)]
    let formatCounts: [(label: String, count: Int)]

    static func compute(entries: [JournalEntry], periodDays: Int, now: Date = .now) -> InsightMetrics {
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .day, value: -periodDays, to: calendar.startOfDay(for: now)) ?? now
        let inPeriod = entries.filter { $0.createdAt >= start }
        let logs = inPeriod.filter { $0.format == .log }

        // Mood / energy daily series.
        let moodSeries = dailyAverage(logs, now: now) { Double($0.moodLog.mood) }
        let energySeries = dailyAverage(logs, now: now) { Double($0.moodLog.energy) }
        let avgMood = average(logs.map { Double($0.moodLog.mood) })
        let avgEnergy = average(logs.map { Double($0.moodLog.energy) })

        // Habit completion rates across all log entries in the window.
        var habitDone: [String: Int] = [:]
        var habitSeen: [String: Int] = [:]
        for log in logs {
            for habit in log.moodLog.habits {
                habitSeen[habit.name, default: 0] += 1
                if habit.done { habitDone[habit.name, default: 0] += 1 }
            }
        }
        let habitRates = habitSeen
            .map { (name: $0.key, rate: Double(habitDone[$0.key] ?? 0) / Double(max(1, $0.value))) }
            .sorted { $0.rate > $1.rate }

        // Feelings frequency.
        var feelingCounts: [String: Int] = [:]
        for log in logs {
            for feeling in log.moodLog.feelings { feelingCounts[feeling, default: 0] += 1 }
        }
        let topFeelings = feelingCounts
            .map { (feeling: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }

        // Format mix.
        var formatCounts: [String: Int] = [:]
        for entry in inPeriod {
            formatCounts[entry.format?.title ?? "Writing", default: 0] += 1
        }
        let formats = formatCounts
            .map { (label: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }

        return InsightMetrics(
            periodDays: periodDays,
            entryCount: inPeriod.count,
            streak: currentStreak(entries: entries, now: now),
            averageMood: avgMood,
            averageEnergy: avgEnergy,
            moodSeries: moodSeries,
            energySeries: energySeries,
            habitRates: habitRates,
            topFeelings: Array(topFeelings.prefix(5)),
            formatCounts: formats
        )
    }

    /// A compact textual summary of the metrics, fed to DeepSeek as structure.
    func promptContext() -> String {
        var lines: [String] = []
        lines.append("Window: last \(periodDays) days.")
        lines.append("Entries: \(entryCount) (current streak \(streak) days).")
        if !moodSeries.isEmpty {
            lines.append(String(format: "Average mood: %.1f/5 (%@).", averageMood, trendWord(moodSeries)))
            lines.append(String(format: "Average energy: %.1f/5 (%@).", averageEnergy, trendWord(energySeries)))
        } else {
            lines.append("No mood logs in this window.")
        }
        if !topFeelings.isEmpty {
            lines.append("Top feelings: " + topFeelings.map { "\($0.feeling) (\($0.count))" }.joined(separator: ", ") + ".")
        }
        if !habitRates.isEmpty {
            let rates = habitRates.prefix(6).map { "\($0.name) \(Int($0.rate * 100))%" }.joined(separator: ", ")
            lines.append("Habit completion: \(rates).")
        }
        if !formatCounts.isEmpty {
            lines.append("Formats: " + formatCounts.map { "\($0.label) \($0.count)" }.joined(separator: ", ") + ".")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: Helpers

    private static func dailyAverage(
        _ logs: [JournalEntry],
        now: Date,
        value: (JournalEntry) -> Double
    ) -> [InsightPoint] {
        let calendar = Calendar.current
        var byDay: [Date: [Double]] = [:]
        for log in logs {
            let day = calendar.startOfDay(for: log.createdAt)
            byDay[day, default: []].append(value(log))
        }
        return byDay
            .map { InsightPoint(date: $0.key, value: average($0.value)) }
            .sorted { $0.date < $1.date }
    }

    private static func average(_ values: [Double]) -> Double {
        values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    }

    private static func currentStreak(entries: [JournalEntry], now: Date) -> Int {
        let calendar = Calendar.current
        let days = Set(entries.map { calendar.startOfDay(for: $0.createdAt) })
        guard !days.isEmpty else { return 0 }
        var cursor = calendar.startOfDay(for: now)
        if !days.contains(cursor) {
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
            if !days.contains(cursor) { return 0 }
        }
        var count = 0
        while days.contains(cursor) {
            count += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        return count
    }

    /// "trending up/down/steady" from first-half vs second-half averages.
    private func trendWord(_ series: [InsightPoint]) -> String {
        guard series.count >= 2 else { return "steady" }
        let mid = series.count / 2
        let firstHalf = series.prefix(mid).map(\.value)
        let secondHalf = series.suffix(series.count - mid).map(\.value)
        let a = firstHalf.reduce(0, +) / Double(max(1, firstHalf.count))
        let b = secondHalf.reduce(0, +) / Double(max(1, secondHalf.count))
        if b - a > 0.4 { return "trending up" }
        if a - b > 0.4 { return "trending down" }
        return "steady"
    }
}
