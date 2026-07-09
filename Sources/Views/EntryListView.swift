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
            Group {
                if entries.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
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
            if let onThisDay = onThisDayEntry {
                Section {
                    NavigationLink(value: onThisDay) {
                        OnThisDayCard(entry: onThisDay)
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
            ForEach(entries) { entry in
                NavigationLink(value: entry) {
                    EntryRow(entry: entry)
                }
            }
            .onDelete(perform: delete)
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

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Start journaling", systemImage: "leaf")
                .foregroundStyle(Color.lilac)
        } description: {
            Text("Tap the pencil to open your first prompt.")
        } actions: {
            Button("New Entry") { showingStylePicker = true }
                .buttonStyle(.borderedProminent)
        }
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
