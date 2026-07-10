import SwiftUI
import SwiftData

/// The concrete screen for the Log format: a structured daily check-in — mood
/// and energy, feeling chips, a habit checklist, and an optional note. Mirrors
/// how `DrawingJournalView`/`AudioJournalView` wrap their surfaces, but this one
/// is a form rather than a canvas. Autosaves straight onto the entry.
struct LogJournalView: View {
    @Bindable var entry: JournalEntry

    // Local working copy so the whole form binds cleanly; persisted on change.
    @State private var log = MoodLog()
    @State private var note = ""
    @State private var loaded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                header

                ScalePicker(
                    title: "How's your mood?",
                    value: $log.mood,
                    face: MoodLog.moodFace,
                    label: MoodLog.moodLabel
                )
                ScalePicker(
                    title: "Energy",
                    value: $log.energy,
                    face: energyFace,
                    label: energyLabel
                )

                section("How are you feeling?") {
                    FlowLayout(spacing: 10) {
                        ForEach(MoodLog.feelingOptions, id: \.self) { feeling in
                            SelectableChip(
                                text: feeling,
                                isSelected: log.feelings.contains(feeling)
                            ) { toggleFeeling(feeling) }
                        }
                    }
                }

                section("Today I…") {
                    VStack(spacing: 0) {
                        ForEach($log.habits) { $habit in
                            HabitRow(habit: $habit)
                            if habit.id != log.habits.last?.id {
                                Divider().overlay(Color.homeHairline).padding(.leading, 44)
                            }
                        }
                    }
                    .homeCardBackground()
                }

                section("Anything else?") {
                    TextField("A line about your day…", text: $note, axis: .vertical)
                        .lineLimit(3...8)
                        .padding(14)
                        .homeCardBackground()
                }
            }
            .padding(24)
        }
        .background(
            LinearGradient(colors: [.homeBackgroundTop, .homeBackgroundBottom],
                           startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
        )
        .navigationTitle("Daily Log")
        .navigationBarTitleDisplayMode(.inline)
        .task { loadOnce() }
        .onChange(of: log) { _, newValue in entry.moodLog = newValue }
        .onChange(of: note) { _, newValue in entry.text = newValue }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.createdAt.formatted(.dateTime.weekday(.wide)))
                .font(.system(.largeTitle, design: .serif))
                .foregroundStyle(Color.homeAccentDeep)
            Text(entry.createdAt.formatted(.dateTime.day().month(.wide).year()))
                .font(.system(.subheadline, design: .serif).italic())
                .foregroundStyle(Color.homeSecondary)
        }
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(.headline, design: .serif))
                .foregroundStyle(Color.homeAccentDeep)
            content()
        }
    }

    private func loadOnce() {
        guard !loaded else { return }
        loaded = true
        log = entry.moodLog
        note = entry.text ?? ""
    }

    private func toggleFeeling(_ feeling: String) {
        if let index = log.feelings.firstIndex(of: feeling) {
            log.feelings.remove(at: index)
        } else {
            log.feelings.append(feeling)
        }
    }

    private func energyFace(_ level: Int) -> String {
        ["🪫", "🔋", "🔋", "⚡️", "⚡️"][max(0, min(4, level - 1))]
    }

    private func energyLabel(_ level: Int) -> String {
        ["Drained", "Low", "Steady", "Good", "High"][max(0, min(4, level - 1))]
    }
}

// MARK: - Pieces

/// A 1…5 picker rendered as five tappable faces with a label underneath.
private struct ScalePicker: View {
    let title: String
    @Binding var value: Int
    let face: (Int) -> String
    let label: (Int) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.system(.headline, design: .serif))
                    .foregroundStyle(Color.homeAccentDeep)
                Spacer()
                Text(label(value))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.homeAccent)
            }
            HStack(spacing: 10) {
                ForEach(1...5, id: \.self) { level in
                    Button {
                        withAnimation(.snappy(duration: 0.2)) { value = level }
                    } label: {
                        Text(face(level))
                            .font(.system(size: 30))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(level == value ? Color.homeAccent.opacity(0.18) : Color.homeCard)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(level == value ? Color.homeAccent : Color.homeHairline,
                                                    lineWidth: level == value ? 1.5 : 1)
                                    )
                            )
                            .scaleEffect(level == value ? 1.06 : 1)
                            .grayscale(level == value ? 0 : 0.4)
                            .opacity(level == value ? 1 : 0.7)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// A multi-select feeling pill.
private struct SelectableChip: View {
    let text: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.footnote.weight(.medium))
                .foregroundStyle(isSelected ? .white : Color.homeAccentDeep)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.homeAccent : Color.homeCard)
                        .overlay(Capsule().stroke(isSelected ? .clear : Color.homeHairline, lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
    }
}

/// One checklist row with a tappable check.
private struct HabitRow: View {
    @Binding var habit: HabitCheck

    var body: some View {
        Button {
            withAnimation(.snappy(duration: 0.15)) { habit.done.toggle() }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: habit.done ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(habit.done ? Color.homeAccent : Color.homeSecondary.opacity(0.5))
                Text(habit.name)
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(Color.homeAccentDeep)
                    .strikethrough(habit.done, color: Color.homeSecondary)
                Spacer()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
