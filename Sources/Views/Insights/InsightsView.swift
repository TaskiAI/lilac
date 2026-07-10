import SwiftUI
import SwiftData
import Charts

/// The Insights dashboard. Local metrics (computed live from entries) drive the
/// tiles and charts; the DeepSeek-generated `InsightReport` provides the
/// narrative and the suggestions that feed back into the app (start a tailored
/// prompt, adopt a suggested focus).
struct InsightsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \JournalEntry.createdAt, order: .reverse) private var entries: [JournalEntry]
    @Query(sort: \InsightReport.generatedAt, order: .reverse) private var reports: [InsightReport]

    @AppStorage(FocusAreas.storageKey) private var focusRaw = FocusAreas.encode(FocusAreas.defaults)
    @AppStorage(InsightEngine.enabledKey) private var insightsEnabled = true

    @State private var isGenerating = false

    /// Starts a journal entry from a suggested prompt (host handles navigation).
    var onStartPrompt: (String) -> Void = { _ in }

    private let periodDays = 14
    private var engine: InsightEngine { InsightEngine(context: context) }
    private var metrics: InsightMetrics { InsightMetrics.compute(entries: entries, periodDays: periodDays) }
    private var report: InsightReport? { reports.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    tiles
                    if !metrics.moodSeries.isEmpty { moodChart }
                    if !metrics.habitRates.isEmpty { habitChart }
                    narrative
                    privacyFooter
                }
                .padding(24)
            }
            .background(
                LinearGradient(colors: [.homeBackgroundTop, .homeBackgroundBottom],
                               startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            )
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await regenerate() }
                    } label: {
                        if isGenerating {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(isGenerating)
                }
            }
        }
        .tint(.homeAccent)
        .task {
            if reports.isEmpty { await regenerate() }
        }
    }

    // MARK: Tiles

    private var tiles: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            MetricTile(value: "\(metrics.entryCount)", label: "Entries · \(periodDays)d", symbol: "square.and.pencil")
            MetricTile(value: "\(metrics.streak)", label: "Day streak", symbol: "flame")
            MetricTile(
                value: metrics.averageMood > 0 ? MoodLog.moodFace(Int(metrics.averageMood.rounded())) : "—",
                label: metrics.averageMood > 0 ? String(format: "Mood %.1f/5", metrics.averageMood) : "Mood —",
                symbol: "face.smiling"
            )
            MetricTile(
                value: metrics.averageEnergy > 0 ? String(format: "%.1f", metrics.averageEnergy) : "—",
                label: "Energy /5",
                symbol: "bolt"
            )
        }
    }

    // MARK: Charts

    private var moodChart: some View {
        InsightCard(title: "Mood & energy") {
            Chart {
                ForEach(metrics.moodSeries) { point in
                    LineMark(
                        x: .value("Day", point.date, unit: .day),
                        y: .value("Mood", point.value),
                        series: .value("Series", "Mood")
                    )
                    .foregroundStyle(Color.homeAccent)
                    .interpolationMethod(.catmullRom)
                    .symbol(.circle)
                }
                ForEach(metrics.energySeries) { point in
                    LineMark(
                        x: .value("Day", point.date, unit: .day),
                        y: .value("Energy", point.value),
                        series: .value("Series", "Energy")
                    )
                    .foregroundStyle(Color.homeAccentDeep.opacity(0.5))
                    .interpolationMethod(.catmullRom)
                }
            }
            .chartYScale(domain: 1.0...5.0)
            .chartLegend(.hidden)
            .frame(height: 150)
            HStack(spacing: 16) {
                Legend(color: .homeAccent, label: "Mood")
                Legend(color: .homeAccentDeep.opacity(0.5), label: "Energy")
            }
            .font(.caption2)
            .foregroundStyle(Color.homeSecondary)
        }
    }

    private var habitChart: some View {
        InsightCard(title: "Habits") {
            Chart {
                ForEach(Array(metrics.habitRates.prefix(6)), id: \.name) { item in
                    BarMark(
                        x: .value("Rate", item.rate),
                        y: .value("Habit", item.name)
                    )
                    .foregroundStyle(Color.homeAccent.gradient)
                    .cornerRadius(5)
                    .annotation(position: .trailing) {
                        Text("\(Int(item.rate * 100))%")
                            .font(.caption2)
                            .foregroundStyle(Color.homeSecondary)
                    }
                }
            }
            .chartXScale(domain: 0.0...1.0)
            .chartXAxis(.hidden)
            .frame(height: CGFloat(min(6, metrics.habitRates.count)) * 40 + 10)
        }
    }

    // MARK: Narrative

    @ViewBuilder
    private var narrative: some View {
        if let report {
            InsightCard(title: nil) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles").foregroundStyle(Color.homeAccent)
                        Text(report.aiPowered ? "What Lilac notices" : "Summary")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.homeAccentDeep)
                    }
                    if !report.headline.isEmpty {
                        Text(report.headline)
                            .font(.system(.title3, design: .serif).weight(.medium))
                            .foregroundStyle(Color.homeAccentDeep)
                    }
                    if !report.summary.isEmpty {
                        Text(report.summary)
                            .font(.system(.body, design: .serif))
                            .foregroundStyle(Color.homeAccentDeep.opacity(0.85))
                    }
                    if !report.moodNote.isEmpty {
                        Text(report.moodNote)
                            .font(.footnote)
                            .foregroundStyle(Color.homeSecondary)
                    }
                    if !report.themes.isEmpty {
                        FlowLayout(spacing: 8) {
                            ForEach(report.themes, id: \.self) { theme in
                                Text(theme.replacingOccurrences(of: "-", with: " "))
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(Color.homeAccent)
                                    .padding(.horizontal, 10).padding(.vertical, 5)
                                    .background(Color.homeAccent.opacity(0.12), in: Capsule())
                            }
                        }
                    }
                    bulletList("Going well", report.strengths, symbol: "checkmark.circle.fill")
                    bulletList("Gentle nudges", report.gentleNudges, symbol: "leaf.fill")
                    suggestedFocusRow
                    suggestedPromptRow
                }
            }
        } else {
            InsightCard(title: nil) {
                Text("Generating your first insights…")
                    .font(.subheadline)
                    .foregroundStyle(Color.homeSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            }
        }
    }

    @ViewBuilder
    private func bulletList(_ title: String, _ items: [String], symbol: String) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.homeSecondary)
                    .textCase(.uppercase)
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: symbol)
                            .font(.caption)
                            .foregroundStyle(Color.homeAccent)
                        Text(item)
                            .font(.footnote)
                            .foregroundStyle(Color.homeAccentDeep)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var suggestedFocusRow: some View {
        if let report, !report.suggestedFocuses.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Suggested focus")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.homeSecondary)
                    .textCase(.uppercase)
                FlowLayout(spacing: 8) {
                    ForEach(report.suggestedFocuses, id: \.self) { focus in
                        Button { applyFocus(focus) } label: {
                            HStack(spacing: 5) {
                                Image(systemName: hasFocus(focus) ? "checkmark" : "plus")
                                Text(focus)
                            }
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(hasFocus(focus) ? Color.homeSecondary : Color.homeAccentDeep)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(
                                Capsule().fill(Color.homeCard)
                                    .overlay(Capsule().stroke(Color.homeHairline, lineWidth: 1))
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(hasFocus(focus))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var suggestedPromptRow: some View {
        if let report, !report.suggestedPrompt.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(report.suggestedPrompt)
                    .font(.system(.subheadline, design: .serif))
                    .foregroundStyle(Color.homeAccentDeep)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    dismiss()
                    onStartPrompt(report.suggestedPrompt)
                } label: {
                    Label("Write on this", systemImage: "square.and.pencil")
                        .font(.system(.subheadline, design: .rounded).weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(Capsule().fill(Color.homeAccent))
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.homeTint))
        }
    }

    private var privacyFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $insightsEnabled) {
                Text("AI insights")
                    .font(.subheadline)
                    .foregroundStyle(Color.homeAccentDeep)
            }
            .tint(.homeAccent)
            Text("When on, Lilac sends a summary of recent entries to DeepSeek to generate insights. Turn off to keep everything on-device (you'll still get local trends).")
                .font(.caption2)
                .foregroundStyle(Color.homeSecondary)
            if let report {
                Text("Updated \(report.generatedAt.formatted(date: .abbreviated, time: .shortened))\(report.aiPowered ? "" : " · local only")")
                    .font(.caption2)
                    .foregroundStyle(Color.homeSecondary.opacity(0.8))
            }
        }
    }

    // MARK: Actions

    private func regenerate() async {
        guard !isGenerating else { return }
        isGenerating = true
        await engine.generate(periodDays: periodDays, focuses: FocusAreas.decode(focusRaw))
        isGenerating = false
    }

    private func hasFocus(_ focus: String) -> Bool {
        FocusAreas.decode(focusRaw).contains { $0.caseInsensitiveCompare(focus) == .orderedSame }
    }

    private func applyFocus(_ focus: String) {
        var list = FocusAreas.decode(focusRaw)
        guard !list.contains(where: { $0.caseInsensitiveCompare(focus) == .orderedSame }) else { return }
        list.append(focus)
        focusRaw = FocusAreas.encode(list)
    }
}

// MARK: - Pieces

private struct MetricTile: View {
    let value: String
    let label: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.subheadline)
                .foregroundStyle(Color.homeAccent)
            Text(value)
                .font(.system(.title2, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.homeAccentDeep)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.homeSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .homeCardBackground()
    }
}

private struct InsightCard<Content: View>: View {
    let title: String?
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title)
                    .font(.system(.headline, design: .serif))
                    .foregroundStyle(Color.homeAccentDeep)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .homeCardBackground()
    }
}

private struct Legend: View {
    let color: Color
    let label: String
    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
        }
    }
}
