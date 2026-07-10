import SwiftUI
import SwiftData

/// The notifications center: gentle, data-driven nudges (no entry today, a
/// resurfaced past entry, a focus reminder, a streak) plus the daily-reminder
/// schedule. Nudges are derived live from the journal — nothing is stored.
struct NotificationsView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \JournalEntry.createdAt, order: .reverse) private var entries: [JournalEntry]

    /// Called when a nudge asks to start today's journal.
    var onStartJournal: () -> Void = {}

    @AppStorage("reminder.enabled") private var reminderEnabled = false
    @AppStorage("reminder.hour") private var reminderHour = 20
    @AppStorage("reminder.minute") private var reminderMinute = 0
    @AppStorage(FocusAreas.storageKey) private var focusRaw = FocusAreas.encode(FocusAreas.defaults)

    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    from: DateComponents(hour: reminderHour, minute: reminderMinute)
                ) ?? .now
            },
            set: { newValue in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                reminderHour = comps.hour ?? 20
                reminderMinute = comps.minute ?? 0
                rescheduleIfEnabled()
            }
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if nudges.isEmpty {
                        Text("You're all caught up.")
                            .font(.subheadline)
                            .foregroundStyle(Color.homeSecondary)
                    } else {
                        ForEach(nudges) { nudge in
                            NudgeRow(nudge: nudge) { handle(nudge) }
                        }
                    }
                } header: {
                    Text("Nudges")
                }

                Section {
                    Toggle("Daily reminder", isOn: $reminderEnabled)
                        .tint(.homeAccent)
                        .onChange(of: reminderEnabled) { _, on in
                            if on {
                                Task { await ReminderScheduler.schedule(hour: reminderHour, minute: reminderMinute) }
                            } else {
                                ReminderScheduler.cancel()
                            }
                        }
                    if reminderEnabled {
                        DatePicker("Remind me at", selection: reminderTime, displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("Reminders")
                } footer: {
                    Text("A gentle daily nudge to take a moment for yourself.")
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(.homeAccent)
    }

    // MARK: Nudges

    private var nudges: [Nudge] {
        var result: [Nudge] = []
        let calendar = Calendar.current

        let wroteToday = entries.contains { calendar.isDateInToday($0.createdAt) }
        if !wroteToday {
            result.append(Nudge(
                icon: "pencil.line",
                tint: .homeAccent,
                title: "You haven't written today",
                message: "A few minutes on the page can settle the day. Start whenever you're ready.",
                action: .startJournal
            ))
        }

        if let resurfaced = onThisDay {
            let days = calendar.dateComponents([.day], from: resurfaced.createdAt, to: .now).day ?? 0
            let label = days >= 30 ? "\(days / 30) month(s) ago" : days >= 7 ? "\(days / 7) week(s) ago" : "\(days) days ago"
            let preview = resurfaced.prompt.isEmpty ? (resurfaced.text ?? "an entry") : resurfaced.prompt
            result.append(Nudge(
                icon: "clock.arrow.circlepath",
                tint: .homeAccentDeep,
                title: "From \(label)",
                message: "You wrote: \"\(String(preview.prefix(80)))\". Worth revisiting?",
                action: .none
            ))
        }

        let focuses = FocusAreas.decode(focusRaw)
        if let focus = focuses.first {
            result.append(Nudge(
                icon: FocusAreas.icon(for: focus),
                tint: .homeAccent,
                title: "Your focus: \(focus)",
                message: "Could today's entry lean toward this? Small, steady steps.",
                action: .none
            ))
        }

        if streak >= 2 {
            result.append(Nudge(
                icon: "flame",
                tint: .homeAccentDeep,
                title: "\(streak)-day streak",
                message: "You've shown up \(streak) days in a row. Keep the thread going.",
                action: .none
            ))
        }

        return result
    }

    /// The most recent entry that lands on a past week/month anniversary of today.
    private var onThisDay: JournalEntry? {
        let calendar = Calendar.current
        for offset in [7, 14, 30, 60, 90, 365] {
            guard let target = calendar.date(byAdding: .day, value: -offset, to: .now) else { continue }
            if let match = entries.first(where: { calendar.isDate($0.createdAt, inSameDayAs: target) }) {
                return match
            }
        }
        return nil
    }

    /// Consecutive days (ending today or yesterday) with at least one entry.
    private var streak: Int {
        let calendar = Calendar.current
        let days = Set(entries.map { calendar.startOfDay(for: $0.createdAt) })
        guard !days.isEmpty else { return 0 }
        var count = 0
        var cursor = calendar.startOfDay(for: .now)
        if !days.contains(cursor) {
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
            if !days.contains(cursor) { return 0 }
        }
        while days.contains(cursor) {
            count += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        return count
    }

    private func handle(_ nudge: Nudge) {
        switch nudge.action {
        case .startJournal:
            dismiss()
            onStartJournal()
        case .none:
            break
        }
    }

    private func rescheduleIfEnabled() {
        guard reminderEnabled else { return }
        Task { await ReminderScheduler.schedule(hour: reminderHour, minute: reminderMinute) }
    }
}

/// A single derived nudge.
private struct Nudge: Identifiable {
    enum Action { case startJournal, none }

    let id = UUID()
    let icon: String
    let tint: Color
    let title: String
    let message: String
    let action: Action
}

private struct NudgeRow: View {
    let nudge: Nudge
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle().fill(Color.homeTint).frame(width: 40, height: 40)
                    Image(systemName: nudge.icon)
                        .font(.subheadline)
                        .foregroundStyle(nudge.tint)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(nudge.title)
                        .font(.system(.subheadline, design: .serif).weight(.medium))
                        .foregroundStyle(Color.homeAccentDeep)
                    Text(nudge.message)
                        .font(.footnote)
                        .foregroundStyle(Color.homeSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                if nudge.action != .none {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.homeSecondary.opacity(0.6))
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(nudge.action == .none)
    }
}
