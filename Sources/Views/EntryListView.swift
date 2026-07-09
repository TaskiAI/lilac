import SwiftUI
import SwiftData
import PencilKit

/// The home screen: your journal, newest entry first.
struct EntryListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \JournalEntry.createdAt, order: .reverse) private var entries: [JournalEntry]
    @State private var path: [JournalEntry] = []
    @State private var showingStylePicker = false

    var body: some View {
        NavigationStack(path: $path) {
            list
            .navigationTitle("Lilac")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingStylePicker = true
                    } label: {
                        Label("New Entry", systemImage: "square.and.pencil")
                    }
                }
            }
            .navigationDestination(for: JournalEntry.self) { entry in
                EntryEditorView(entry: entry)
            }
            .sheet(isPresented: $showingStylePicker) {
                StylePickerView(onPick: newEntry)
            }
        }
    }

    private var list: some View {
        List {
            Section {
                DailyJournalCard(
                    recommended: RecommendedPrompts.today(),
                    onStart: startDailyJournal,
                    onPick: startDailyJournal(with:)
                )
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            if let onThisDay = onThisDayEntry {
                Section {
                    NavigationLink(value: onThisDay) {
                        OnThisDayCard(entry: onThisDay)
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            if entries.isEmpty {
                Section {
                    Text("Your entries will appear here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 12)
                }
                .listRowBackground(Color.clear)
            } else {
                Section("Entries") {
                    ForEach(entries) { entry in
                        NavigationLink(value: entry) {
                            EntryRow(entry: entry)
                        }
                    }
                    .onDelete(perform: delete)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    /// Finds a past entry from a previous week/month to resurface for
    /// periodic re-reading, checking a handful of fixed day-offsets.
    private var onThisDayEntry: JournalEntry? {
        let calendar = Calendar.current
        let today = Date()
        let dayOffsets = [7, 14, 21, 30, 60, 90]
        for offset in dayOffsets {
            guard let target = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            if let match = entries.first(where: { calendar.isDate($0.createdAt, inSameDayAs: target) }) {
                return match
            }
        }
        return nil
    }

    /// The daily reminder's primary action: start today's journal as a free-flow
    /// check-in, seeded instantly then upgraded to a generated prompt.
    private func startDailyJournal() {
        newEntry(style: .freeFlow, sessionLength: .quick)
    }

    /// Start a journal from a chosen recommended prompt. Uses the prompt exactly
    /// as picked — no AI upgrade — since the writer selected this one on purpose.
    private func startDailyJournal(with recommended: RecommendedPrompt) {
        let entry = JournalEntry(
            prompt: recommended.text,
            style: recommended.style,
            sessionLength: .quick
        )
        context.insert(entry)
        path.append(entry)
    }

    private func newEntry(style: JournalStyle, sessionLength: SessionLength) {
        // Seed instantly from the curated bank so navigation never waits on the
        // network, then upgrade to a freshly generated prompt in the background.
        // If the engine is offline the seed simply stays.
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

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            context.delete(entries[index])
        }
    }
}

/// The home screen's hero: a standing reminder to journal today. Tapping the
/// body starts today's entry; the dropdown offers recommended prompts to start
/// from instead. The recommendations are curated for now and will later be
/// driven by therapy sessions and other AI analyzers.
private struct DailyJournalCard: View {
    let recommended: [RecommendedPrompt]
    let onStart: () -> Void
    let onPick: (RecommendedPrompt) -> Void

    private var today: String {
        Date().formatted(.dateTime.weekday(.wide).month().day())
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onStart) {
                HStack(spacing: 14) {
                    Image(systemName: "leaf")
                        .font(.title2)
                        .foregroundStyle(Color.lilac)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Daily journal")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(today)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "square.and.pencil")
                        .font(.title3)
                        .foregroundStyle(Color.lilac)
                }
                .padding(16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if !recommended.isEmpty {
                Divider().overlay(Color.lilac.opacity(0.25))

                Menu {
                    ForEach(recommended) { prompt in
                        Button {
                            onPick(prompt)
                        } label: {
                            Label(prompt.text, systemImage: prompt.style.icon)
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                        Text("Recommended prompts")
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.lilac)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
            }
        }
        .background(Color.lilacSoft, in: RoundedRectangle(cornerRadius: 16))
    }
}

/// A single row: the prompt, the date, and a thumbnail of the handwriting.
private struct EntryRow: View {
    let entry: JournalEntry

    private var thumbnail: UIImage? {
        guard let drawing = try? PKDrawing(data: entry.drawingData),
              !drawing.bounds.isEmpty else { return nil }
        return drawing.image(from: drawing.bounds, scale: 1)
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: entry.style.icon)
                .font(.subheadline)
                .foregroundStyle(Color.lilac)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.prompt)
                    .font(.body.weight(.medium))
                    .lineLimit(2)
                Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 56, height: 56)
                    .background(Color.lilacSoft, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.vertical, 4)
    }
}

/// A card surfacing a past entry for periodic re-reading, e.g. "1 week ago".
private struct OnThisDayCard: View {
    let entry: JournalEntry

    private var relativeLabel: String {
        let days = Calendar.current.dateComponents([.day], from: entry.createdAt, to: .now).day ?? 0
        if days >= 60 { return "\(days / 30) months ago" }
        if days >= 14 { return "\(days / 7) weeks ago" }
        if days >= 7 { return "1 week ago" }
        return "\(days) days ago"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.title3)
                .foregroundStyle(Color.lilac)
            VStack(alignment: .leading, spacing: 4) {
                Text("On this day · \(relativeLabel)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.lilac)
                    .textCase(.uppercase)
                Text(entry.prompt)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.lilacSoft.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
    }
}
