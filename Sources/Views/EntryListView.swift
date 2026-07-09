import SwiftUI
import SwiftData
import PencilKit

/// The home screen: your journal, newest entry first.
struct EntryListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \JournalEntry.createdAt, order: .reverse) private var entries: [JournalEntry]
    @State private var path: [JournalEntry] = []

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
                    Button(action: newEntry) {
                        Label("New Entry", systemImage: "square.and.pencil")
                    }
                }
            }
            .navigationDestination(for: JournalEntry.self) { entry in
                EntryEditorView(entry: entry)
            }
        }
    }

    private var list: some View {
        List {
            ForEach(entries) { entry in
                NavigationLink(value: entry) {
                    EntryRow(entry: entry)
                }
            }
            .onDelete(perform: delete)
        }
        .listStyle(.insetGrouped)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Start journaling", systemImage: "leaf")
                .foregroundStyle(Color.lilac)
        } description: {
            Text("Tap the pencil to open your first prompt.")
        } actions: {
            Button("New Entry", action: newEntry)
                .buttonStyle(.borderedProminent)
        }
    }

    private func newEntry() {
        let entry = JournalEntry(prompt: PromptBank.random())
        context.insert(entry)
        path.append(entry)
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
