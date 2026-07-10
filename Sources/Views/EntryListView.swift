import SwiftUI
import SwiftData
import PencilKit

/// The home screen — a calm, lavender landing page. It greets the writer by
/// time of day, shows today's entries, and offers the ways in: start today's
/// journal, start an activity, quick-write, and browse history.
struct EntryListView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var auth: AuthManager
    @Query(sort: \JournalEntry.createdAt, order: .reverse) private var entries: [JournalEntry]
    @Query(sort: \InsightReport.generatedAt, order: .reverse) private var reports: [InsightReport]

    @State private var path: [JournalEntry] = []
    @State private var selectedTab: HomeTab = .journal

    // Sheets / flows.
    @State private var showingStylePicker = false     // Quick write
    @State private var showingAllEntries = false       // View all / History
    @State private var showingActivities = false       // Start an activity
    @State private var showingCompanion = false        // AI companion
    @State private var showingNotifications = false     // bell
    @State private var showingFocusEditor = false
    @State private var showingSettings = false          // gear
    @State private var showingInsights = false          // insights card
    @State private var showingNudge = false             // "need a nudge?"

    @AppStorage(FocusAreas.storageKey) private var focusRaw = FocusAreas.encode(FocusAreas.defaults)

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                LinearGradient(
                    colors: [.homeBackgroundTop, .homeBackgroundBottom],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                Group {
                    if selectedTab == .journal {
                        home
                    } else {
                        MeetingsView()
                    }
                }
            }
            .navigationBarHidden(true)
            .safeAreaInset(edge: .bottom) { tabBar }
            .navigationDestination(for: JournalEntry.self) { journalDestination(for: $0) }
            .sheet(isPresented: $showingStylePicker) {
                StylePickerView(onPick: newEntry)
            }
            .sheet(isPresented: $showingAllEntries) { AllEntriesView() }
            .sheet(isPresented: $showingActivities) { ActivitiesSheet() }
            .sheet(isPresented: $showingFocusEditor) { FocusEditorView(raw: $focusRaw) }
            .sheet(isPresented: $showingCompanion) {
                CompanionView()
            }
            .sheet(isPresented: $showingNotifications) {
                NotificationsView(onStartJournal: startDailyJournal)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView().environmentObject(auth)
            }
            .sheet(isPresented: $showingInsights) {
                InsightsView(onStartPrompt: { startPromptedEntry($0) })
            }
            .sheet(isPresented: $showingNudge) {
                PromptChooserView(
                    suggestions: PromptSuggestions.list(
                        insight: reports.first,
                        focuses: FocusAreas.decode(focusRaw)
                    ),
                    onPick: { startPromptedEntry($0.text, style: $0.style) }
                )
            }
        }
        .tint(.homeAccent)
    }

    // MARK: Home content

    private var home: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                header
                dateBlock
                VStack(alignment: .leading, spacing: 10) {
                    PrimaryActionCard(
                        icon: "pencil",
                        title: "Start daily journal",
                        action: startDailyJournal
                    )
                    Button {
                        showingNudge = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                            Text("Need a nudge to begin?")
                        }
                        .font(.footnote)
                        .foregroundStyle(Color.homeAccent)
                        .padding(.leading, 4)
                    }
                    .buttonStyle(.plain)
                }
                todaysJournals
                PrimaryActionCard(
                    icon: "leaf",
                    title: "Start an activity",
                    action: { showingActivities = true }
                )
                focusSection
                InsightsCard(headline: reports.first?.headline) { showingInsights = true }
                quickRow
                HistoryButton { showingAllEntries = true }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(greeting)
                    .font(.system(size: 40, design: .serif))
                    .foregroundStyle(Color.homeAccentDeep)
                Text("You're in the right place.")
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(Color.homeSecondary)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing) {
                HStack(spacing: 18) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.title3)
                            .foregroundStyle(Color.homeAccentDeep)
                    }
                    .accessibilityLabel("Settings")
                    Button {
                        showingNotifications = true
                    } label: {
                        Image(systemName: "bell")
                            .font(.title3)
                            .foregroundStyle(Color.homeAccentDeep)
                    }
                    .accessibilityLabel("Notifications")
                }
                GlowOrbView(size: 78)
                    .padding(.top, 4)
            }
        }
    }

    private var dateBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(todayString)
                .font(.system(.title3, design: .serif).weight(.medium))
                .foregroundStyle(Color.homeAccentDeep)
            Text(PromptSuggestions.dailyLine(insight: reports.first, focuses: FocusAreas.decode(focusRaw)))
                .font(.subheadline)
                .foregroundStyle(Color.homeSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var todaysJournals: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Today's journals", action: "View all") {
                showingAllEntries = true
            }
            if todaysEntries.isEmpty {
                Text("Nothing yet today — start above whenever you're ready.")
                    .font(.subheadline)
                    .foregroundStyle(Color.homeSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .homeCardBackground()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(todaysEntries.enumerated()), id: \.element.id) { index, entry in
                        if index > 0 {
                            Divider().overlay(Color.homeHairline).padding(.leading, 60)
                        }
                        NavigationLink(value: entry) {
                            TodayJournalRow(entry: entry)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .homeCardBackground()
            }
        }
    }

    private var focusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Your current focus", action: "Edit") {
                showingFocusEditor = true
            }
            FlowLayout(spacing: 10) {
                ForEach(focusAreas, id: \.self) { focus in
                    FocusChip(text: focus)
                }
            }
        }
    }

    private var quickRow: some View {
        HStack(spacing: 14) {
            SmallActionButton(icon: "pencil", title: "Quick write") {
                showingStylePicker = true
            }
            SmallActionButton(icon: "bubble.left.and.text.bubble.right", title: "AI companion") {
                showingCompanion = true
            }
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            TabBarItem(icon: "book", title: "Journal", isSelected: selectedTab == .journal) {
                selectedTab = .journal
            }
            TabBarItem(icon: "person.2", title: "Meetings", isSelected: selectedTab == .meetings) {
                selectedTab = .meetings
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(
            Capsule().fill(Color.homeCard)
                .shadow(color: Color.homeAccent.opacity(0.14), radius: 14, x: 0, y: 4)
        )
        .overlay(Capsule().stroke(Color.homeHairline, lineWidth: 1))
        .padding(.horizontal, 40)
        .padding(.bottom, 6)
    }

    // MARK: Dynamic values

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    private var todayString: String {
        Date().formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    private var todaysEntries: [JournalEntry] {
        entries.filter { Calendar.current.isDateInToday($0.createdAt) }
    }

    private var focusAreas: [String] {
        FocusAreas.decode(focusRaw)
    }

    // MARK: Actions

    /// The primary CTA: start today's journal as a free-flow check-in, seeded
    /// instantly then upgraded to a generated prompt.
    private func startDailyJournal() {
        newEntry(style: .freeFlow, sessionLength: .quick)
    }

    /// Start a writing entry from a specific prompt (the insight's "write on
    /// this" suggestion, or a chosen nudge). Uses the prompt exactly — no AI
    /// rewrite — since the writer picked it on purpose.
    private func startPromptedEntry(_ prompt: String, style: JournalStyle = .freeFlow) {
        let entry = JournalEntry(prompt: prompt, style: style, sessionLength: .quick)
        context.insert(entry)
        path.append(entry)
    }

    private func newEntry(style: JournalStyle, sessionLength: SessionLength) {
        // Seed instantly from the curated bank so navigation never waits on the
        // network, then upgrade to a freshly generated prompt in the background.
        let seeded = PromptBank.random(for: style)
        let entry = JournalEntry(
            prompt: seeded,
            style: style,
            sessionLength: sessionLength
        )
        context.insert(entry)
        showingStylePicker = false
        path.append(entry)

        Task { @MainActor in
            let generated = await PromptEngine.shared.prompt(for: style, excluding: seeded)
            entry.prompt = generated
        }
    }
}

private enum HomeTab { case journal, meetings }

// MARK: - Home components

/// The big lavender call-to-action cards ("Start daily journal", "Start an
/// activity"): a white icon disc, a serif title, and a trailing chevron disc.
private struct PrimaryActionCard: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle().fill(Color.white).frame(width: 52, height: 52)
                        .shadow(color: Color.homeAccent.opacity(0.12), radius: 6, x: 0, y: 2)
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(Color.homeAccent)
                }
                Text(title)
                    .font(.system(.title3, design: .serif).weight(.medium))
                    .foregroundStyle(Color.homeAccentDeep)
                Spacer(minLength: 8)
                ChevronDisc()
            }
            .padding(18)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color.homeTint)
            )
            .contentShape(RoundedRectangle(cornerRadius: 22))
        }
        .buttonStyle(.plain)
    }
}

/// A section title with a trailing text action ("View all", "Edit").
private struct SectionHeader: View {
    let title: String
    let action: String
    let onTap: () -> Void

    var body: some View {
        HStack {
            Text(title)
                .font(.system(.title3, design: .serif))
                .foregroundStyle(Color.homeAccentDeep)
            Spacer()
            Button(action: onTap) {
                Text(action)
                    .font(.subheadline)
                    .foregroundStyle(Color.homeAccent)
            }
        }
    }
}

/// One row in "Today's journals": a soft icon disc (sun for day, moon for
/// evening, or the format's own glyph), a title, and the time it was written.
private struct TodayJournalRow: View {
    let entry: JournalEntry

    private var hour: Int { Calendar.current.component(.hour, from: entry.createdAt) }

    private var iconName: String {
        if let format = entry.format { return format.icon }
        return hour >= 17 || hour < 5 ? "moon" : "sun.max"
    }

    private var title: String {
        if let t = entry.title, !t.isEmpty { return t }
        if let format = entry.format { return "\(format.title) Journal" }
        switch hour {
        case 5..<12: return "Morning Journal"
        case 12..<17: return "Afternoon Journal"
        default: return "Evening Journal"
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.homeTint).frame(width: 40, height: 40)
                Image(systemName: iconName)
                    .font(.subheadline)
                    .foregroundStyle(Color.homeAccent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.body, design: .serif).weight(.medium))
                    .foregroundStyle(Color.homeAccentDeep)
                Text(entry.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(Color.homeSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.homeSecondary.opacity(0.6))
        }
        .padding(16)
        .contentShape(Rectangle())
    }
}

/// A single "current focus" pill.
private struct FocusChip: View {
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: FocusAreas.icon(for: text))
                .font(.caption)
                .foregroundStyle(Color.homeAccent)
            Text(text)
                .font(.footnote)
                .foregroundStyle(Color.homeSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            Capsule().fill(Color.homeCard)
                .overlay(Capsule().stroke(Color.homeHairline, lineWidth: 1))
        )
    }
}

/// The paired white buttons ("Quick write", "AI companion").
private struct SmallActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(Color.homeTint).frame(width: 38, height: 38)
                    Image(systemName: icon)
                        .font(.subheadline)
                        .foregroundStyle(Color.homeAccent)
                }
                Text(title)
                    .font(.system(.subheadline, design: .serif).weight(.medium))
                    .foregroundStyle(Color.homeAccentDeep)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.homeSecondary.opacity(0.6))
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .homeCardBackground()
        }
        .buttonStyle(.plain)
    }
}

/// The full-width "History" button.
private struct HistoryButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.homeTint).frame(width: 44, height: 44)
                    Image(systemName: "book")
                        .font(.subheadline)
                        .foregroundStyle(Color.homeAccent)
                }
                Text("History")
                    .font(.system(.body, design: .serif).weight(.medium))
                    .foregroundStyle(Color.homeAccentDeep)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.homeSecondary.opacity(0.6))
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .homeCardBackground()
        }
        .buttonStyle(.plain)
    }
}

/// The home entry point into Insights. Shows the latest AI headline as a teaser
/// when one exists, or an invitation to discover patterns.
private struct InsightsCard: View {
    let headline: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.homeTint).frame(width: 44, height: 44)
                    Image(systemName: "sparkles")
                        .font(.subheadline)
                        .foregroundStyle(Color.homeAccent)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Insights")
                        .font(.system(.body, design: .serif).weight(.medium))
                        .foregroundStyle(Color.homeAccentDeep)
                    Text(headline?.isEmpty == false ? headline! : "See what your journaling reveals")
                        .font(.caption)
                        .foregroundStyle(Color.homeSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.homeSecondary.opacity(0.6))
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .homeCardBackground()
        }
        .buttonStyle(.plain)
    }
}

/// A small chevron inside a faint disc, used on the primary cards.
private struct ChevronDisc: View {
    var body: some View {
        ZStack {
            Circle().fill(Color.homeAccent.opacity(0.14)).frame(width: 34, height: 34)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.homeAccent)
        }
    }
}

/// One item in the bottom tab bar.
private struct TabBarItem: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                    Text(title)
                        .font(.system(.subheadline, design: .serif))
                }
                .foregroundStyle(isSelected ? Color.homeAccent : Color.homeSecondary)
                Rectangle()
                    .fill(isSelected ? Color.homeAccent : .clear)
                    .frame(width: 26, height: 2)
                    .clipShape(Capsule())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Activities sheet

/// Opened from "Start an activity": the Rewind resurfacing activity plus the
/// other ways to journal (drawing, photo, audio, …).
private struct ActivitiesSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var path: [JournalEntry] = []

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Reflect")
                        .font(.system(.title3, design: .serif))
                        .foregroundStyle(Color.homeAccentDeep)
                    RewindActivitySection()

                    Text("More ways to journal")
                        .font(.system(.title3, design: .serif))
                        .foregroundStyle(Color.homeAccentDeep)
                    FormatGallery(onSelect: create)
                        .padding(.horizontal, -20)
                }
                .padding(20)
            }
            .background(
                LinearGradient(
                    colors: [.homeBackgroundTop, .homeBackgroundBottom],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Activities")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: JournalEntry.self) { journalDestination(for: $0) }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(.homeAccent)
    }

    /// Every format now has a real editor — create the entry and open it.
    private func create(_ format: JournalFormat) {
        let entry = JournalEntry(prompt: "", format: format)
        context.insert(entry)
        path.append(entry)
    }
}
