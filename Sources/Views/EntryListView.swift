import SwiftUI
import SwiftData

/// The home screen — a calm, intentional dashboard: greeting, goals, this
/// week's moods + entries, a quote, and today's writing prompt. Four tabs at
/// the bottom (Home / Sessions / History / Journey).
struct EntryListView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var auth: AuthManager
    @Query(sort: \JournalEntry.createdAt, order: .reverse) private var entries: [JournalEntry]

    @State private var path: [JournalEntry] = []
    @State private var selectedTab: HomeTab = .home
    @State private var showingSettings = false
    @State private var showingGoals = false
    @State private var showingCreate = false
    @State private var promptQuestion = ""

    @AppStorage(Goals.storageKey) private var goalsRaw = Goals.encode(Goals.defaults)

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                LinearGradient(
                    colors: [.homeBackgroundTop, .homeBackgroundBottom],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                tabContent
            }
            .navigationBarHidden(true)
            .safeAreaInset(edge: .bottom) { bottomBar }
            .navigationDestination(for: JournalEntry.self) { journalDestination(for: $0) }
            .sheet(isPresented: $showingSettings) { SettingsView().environmentObject(auth) }
            .sheet(isPresented: $showingGoals) { GoalsEditorView(raw: $goalsRaw) }
            .sheet(isPresented: $showingCreate) {
                CreateSheet(onWriting: createWriting, onFormat: createFormat)
            }
            .onAppear { if promptQuestion.isEmpty { promptQuestion = Self.seededQuestion() } }
        }
        .tint(.homeAccent)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .home:
            home
        case .sessions:
            SessionsHub()
        case .history:
            AllEntriesView(embedded: true)
        case .journey:
            InsightsView(
                onStartPrompt: { prompt in
                    selectedTab = .home
                    startPromptedEntry(prompt)
                },
                embedded: true
            )
        }
    }

    // MARK: Home

    private var home: some View {
        ScrollView {
            VStack(spacing: 18) {
                GreetingHeader(greeting: greeting, date: dateString) { showingSettings = true }
                QuoteCard(text: Self.seededQuote())
                PromptCard(
                    question: promptQuestion,
                    onShuffle: { promptQuestion = Self.seededQuestion(excluding: promptQuestion) },
                    onStart: { startPromptedEntry(promptQuestion) }
                )
                GoalsCard(goals: goals) { showingGoals = true }
                WeekCard(
                    weekDays: Self.weekDays(),
                    entries: entries,
                    todays: todaysEntries,
                    onOpen: { startPromptedEntry(nil, existing: $0) },
                    onRecap: { selectedTab = .journey }
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
    }

    // MARK: Bottom bar + floating orb

    private var bottomBar: some View {
        TabBar4(selected: $selectedTab)
            .overlay(alignment: .top) {
                if selectedTab == .home {
                    FloatingOrb { showingCreate = true }
                        .offset(y: -30)
                }
            }
    }

    // MARK: Derived

    private var goals: [Goal] { Goals.decode(goalsRaw) }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    private var dateString: String {
        Date().formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    private var todaysEntries: [JournalEntry] {
        entries
            .filter { Calendar.current.isDateInToday($0.createdAt) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    // MARK: Actions

    /// Start (or open) a writing entry. Pass `existing` to open one; otherwise a
    /// new free-flow entry is created from `prompt` (may be nil for a blank page).
    private func startPromptedEntry(_ prompt: String?, existing: JournalEntry? = nil) {
        if let existing {
            path.append(existing)
            return
        }
        createWriting(prompt, .freeFlow)
    }

    /// Create a writing entry with a chosen prompt + style (from the Create sheet).
    private func createWriting(_ prompt: String?, _ style: JournalStyle) {
        showingCreate = false
        let entry = JournalEntry(prompt: prompt ?? "", style: style, sessionLength: .quick)
        context.insert(entry)
        path.append(entry)
    }

    /// Create a non-writing format entry (audio, drawing, diagram, picture, log).
    private func createFormat(_ format: JournalFormat) {
        showingCreate = false
        let entry = JournalEntry(prompt: "", format: format)
        context.insert(entry)
        path.append(entry)
    }

    // MARK: Content pools

    private static let questions = [
        "What is something you're proud of from this past week?",
        "What drained you this week, and what filled you back up?",
        "When did you feel most like yourself lately?",
        "What's one thing you'd like to carry into next week?",
        "What did you learn about yourself recently?",
        "Who or what are you grateful for right now?",
        "What have you been carrying that you haven't said out loud?"
    ]

    private static let quotes = [
        "Progress is built in small, honest moments. Keep showing up for yourself.",
        "You don't have to have it all figured out to move forward.",
        "Small steps, taken often, become a path.",
        "Be gentle with yourself — you're doing the best you can.",
        "The days you least feel like writing are often the ones worth writing."
    ]

    private static func dayIndex() -> Int {
        Calendar.current.ordinality(of: .day, in: .year, for: .now) ?? 0
    }

    private static func seededQuestion(excluding: String? = nil) -> String {
        let pool = questions.filter { $0 != excluding }
        return pool.randomElement() ?? questions[dayIndex() % questions.count]
    }

    private static func seededQuote() -> String {
        quotes[dayIndex() % quotes.count]
    }

    /// The seven days (Mon…Sun) of the week containing today.
    static func weekDays(now: Date = .now) -> [Date] {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday
        let start = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }
}

enum HomeTab { case home, sessions, history, journey }

// MARK: - Header

private struct GreetingHeader: View {
    let greeting: String
    let date: String
    let onProfile: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(greeting)
                    .font(.system(size: 27, weight: .bold, design: .serif))
                    .foregroundStyle(Color.homeHeading)
                Text(date)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.homeAccent)
            }
            Spacer()
            Button(action: onProfile) {
                Image(systemName: "person")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Color.homeAccent)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.homeTint))
            }
            .accessibilityLabel("Profile and settings")
        }
    }
}

// MARK: - Goals

private struct GoalsCard: View {
    let goals: [Goal]
    let onEdit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onEdit) {
                HStack(spacing: 12) {
                    IconDisc(symbol: "target", size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Goals")
                            .font(.system(.headline, design: .serif))
                            .foregroundStyle(Color.homeHeading)
                        Text("Track your growth and stay intentional.")
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
            .buttonStyle(.plain)

            ForEach(goals) { goal in
                Divider().overlay(Color.homeHairline).padding(.leading, 64)
                GoalRow(goal: goal)
            }
        }
        .homeCardBackground()
    }
}

private struct GoalRow: View {
    let goal: Goal

    var body: some View {
        HStack(spacing: 12) {
            IconDisc(symbol: goal.icon, size: 36)
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(goal.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.homeHeading)
                    Spacer()
                    Text("\(goal.current) / \(goal.target)")
                        .font(.caption)
                        .foregroundStyle(Color.homeSecondary)
                }
                ProgressBarView(fraction: goal.fraction)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

private struct ProgressBarView: View {
    let fraction: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.homeHairline.opacity(0.7))
                Capsule().fill(Color.homeAccent)
                    .frame(width: max(6, geo.size.width * fraction))
            }
        }
        .frame(height: 5)
    }
}

// MARK: - Week card

private struct WeekCard: View {
    let weekDays: [Date]
    let entries: [JournalEntry]
    let todays: [JournalEntry]
    let onOpen: (JournalEntry) -> Void
    let onRecap: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 0) {
                ForEach(weekDays, id: \.self) { day in
                    DayColumn(day: day, entries: entries)
                        .frame(maxWidth: .infinity)
                }
            }

            Divider().overlay(Color.homeHairline)

            VStack(alignment: .leading, spacing: 10) {
                Text("Journal Entries")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.homeSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if todays.isEmpty {
                    Text("Nothing yet today.")
                        .font(.subheadline)
                        .foregroundStyle(Color.homeSecondary)
                        .padding(.vertical, 4)
                } else {
                    ForEach(todays.prefix(3)) { entry in
                        Button { onOpen(entry) } label: { EntryLine(entry: entry) }
                            .buttonStyle(.plain)
                    }
                }
            }

            Button(action: onRecap) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                    Text("Recap Your Week")
                        .font(.system(.subheadline, design: .serif).weight(.medium))
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                }
                .foregroundStyle(Color.homeAccent)
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.homeTint))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .homeCardBackground()
    }
}

private struct DayColumn: View {
    let day: Date
    let entries: [JournalEntry]

    private var calendar: Calendar { .current }
    private var isToday: Bool { calendar.isDateInToday(day) }
    private var isFuture: Bool { calendar.startOfDay(for: day) > calendar.startOfDay(for: .now) }

    private var dayEntries: [JournalEntry] {
        entries.filter { calendar.isDate($0.createdAt, inSameDayAs: day) }
    }

    private var moodLevel: Int? {
        let logs = dayEntries.filter { $0.format == .log }
        if !logs.isEmpty {
            let avg = logs.map { Double($0.moodLog.mood) }.reduce(0, +) / Double(logs.count)
            return Int(avg.rounded())
        }
        return dayEntries.isEmpty ? nil : 3
    }

    var body: some View {
        VStack(spacing: 8) {
            Text(day.formatted(.dateTime.weekday(.abbreviated)))
                .font(.caption2)
                .foregroundStyle(isToday ? Color.homeAccent : Color.homeSecondary)
            Text(day.formatted(.dateTime.day()))
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(isToday ? .white : Color.homeHeading)
                .frame(width: 30, height: 30)
                .background {
                    if isToday { Circle().fill(Color.homeAccent) }
                }
            Group {
                if let moodLevel {
                    MoodFace(level: moodLevel, lineWidth: 1.4)
                        .frame(width: 17, height: 17)
                        .opacity(isFuture ? 0.25 : 1)
                } else {
                    Color.clear.frame(width: 17, height: 17)
                }
            }
            Circle()
                .fill(dayEntries.isEmpty ? .clear : Color.homeAccent)
                .frame(width: 4, height: 4)
        }
    }
}

private struct EntryLine: View {
    let entry: JournalEntry

    private var hour: Int { Calendar.current.component(.hour, from: entry.createdAt) }

    private var name: String {
        if let t = entry.title, !t.isEmpty { return t }
        if let format = entry.format { return "\(format.title) Journal" }
        switch hour {
        case 5..<12: return "Morning Journal"
        case 12..<17: return "Midday Reflection"
        default: return "Evening Journal"
        }
    }

    private var moodLevel: Int {
        entry.format == .log ? entry.moodLog.mood : 3
    }

    var body: some View {
        HStack(spacing: 12) {
            MoodFace(level: moodLevel)
                .frame(width: 19, height: 19)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.homeTint))
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(.subheadline, design: .serif).weight(.medium))
                    .foregroundStyle(Color.homeHeading)
                Text(entry.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(Color.homeSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.homeSecondary.opacity(0.5))
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Quote

private struct QuoteCard: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "quote.opening")
                .font(.title3)
                .foregroundStyle(Color.homeAccent.opacity(0.6))
            Text(text)
                .font(.system(.subheadline, design: .serif))
                .foregroundStyle(Color.homeAccentDeep)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            Image(systemName: "quote.closing")
                .font(.title3)
                .foregroundStyle(Color.homeAccent.opacity(0.6))
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.homeTint))
    }
}

// MARK: - Prompt

private struct PromptCard: View {
    let question: String
    let onShuffle: () -> Void
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            ZStack(alignment: .topTrailing) {
                IconDisc(symbol: "lightbulb", size: 48)
                    .frame(maxWidth: .infinity)
                Button(action: onShuffle) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.subheadline)
                        .foregroundStyle(Color.homeAccent)
                }
                .accessibilityLabel("New prompt")
            }
            Text(question)
                .font(.system(.title3, design: .serif).weight(.semibold))
                .foregroundStyle(Color.homeHeading)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: onStart) {
                Text("Start Writing")
                    .font(.system(.headline, design: .serif))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 13)
                    .background(Capsule().fill(Color.homeAccent))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .homeCardBackground()
    }
}

// MARK: - Floating orb

private struct FloatingOrb: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            GlowOrbView(size: 46)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Start writing")
    }
}

// MARK: - Tab bar

private struct TabBar4: View {
    @Binding var selected: HomeTab

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            item(.home, "house", "Home")
            item(.sessions, "message", "Sessions")
            item(.history, "book", "History")
            item(.journey, "leaf", "Journey")
        }
        .padding(.top, 12)
        .padding(.bottom, 6)
        .padding(.horizontal, 12)
        .background(
            Color.homeCard
                .overlay(alignment: .top) { Rectangle().fill(Color.homeHairline).frame(height: 0.75) }
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func item(_ tab: HomeTab, _ icon: String, _ label: String) -> some View {
        let active = selected == tab
        return Button {
            selected = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(label)
                    .font(.caption2)
                Rectangle()
                    .fill(active ? Color.homeAccent : .clear)
                    .frame(width: 20, height: 2)
                    .clipShape(Capsule())
            }
            .foregroundStyle(active ? Color.homeAccent : Color.homeSecondary)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shared bits

private struct IconDisc: View {
    let symbol: String
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.42))
            .foregroundStyle(Color.homeAccent)
            .frame(width: size, height: size)
            .background(Circle().fill(Color.homeTint))
    }
}

// MARK: - Sessions tab

/// The Sessions tab: a small hub for the AI companion and meetings.
private struct SessionsHub: View {
    @State private var showCompanion = false
    @State private var showMeetings = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Sessions")
                    .font(.system(size: 27, weight: .bold, design: .serif))
                    .foregroundStyle(Color.homeHeading)
                    .padding(.top, 8)

                SessionCard(
                    icon: "message",
                    title: "AI companion",
                    subtitle: "A gentle listener that reflects your words back."
                ) { showCompanion = true }

                SessionCard(
                    icon: "person.2",
                    title: "Meetings",
                    subtitle: "Track therapy sessions and check-ins."
                ) { showMeetings = true }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .sheet(isPresented: $showCompanion) { CompanionView() }
        .sheet(isPresented: $showMeetings) { MeetingsView() }
    }
}

private struct SessionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                IconDisc(symbol: icon, size: 46)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(.headline, design: .serif))
                        .foregroundStyle(Color.homeHeading)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Color.homeSecondary)
                        .fixedSize(horizontal: false, vertical: true)
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
