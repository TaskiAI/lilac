import SwiftUI
import SwiftData
import PencilKit

/// The single place that maps an entry to its editor, so every navigation stack
/// (the home screen and the "all entries" browser) routes the same way.
@ViewBuilder
func journalDestination(for entry: JournalEntry) -> some View {
    switch entry.format {
    case .drawing?, .diagram?:
        DrawingJournalView(entry: entry)
    case .photo?:
        PictureJournalView(entry: entry)
    case .audio?:
        AudioJournalView(entry: entry)
    default:
        EntryEditorView(entry: entry)
    }
}

/// The full reverse-chronological archive, opened from "View all" / "History".
struct AllEntriesView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \JournalEntry.createdAt, order: .reverse) private var entries: [JournalEntry]

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    ContentUnavailableView(
                        "No entries yet",
                        systemImage: "book",
                        description: Text("Your journal entries will appear here.")
                    )
                } else {
                    List {
                        ForEach(entries) { entry in
                            NavigationLink(value: entry) {
                                ArchiveRow(entry: entry)
                            }
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("History")
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

    private func delete(at offsets: IndexSet) {
        for index in offsets { context.delete(entries[index]) }
    }
}

/// A row in the archive: a live thumbnail of the handwriting plus the title/date.
private struct ArchiveRow: View {
    let entry: JournalEntry

    private var thumbnail: UIImage? {
        guard let drawing = try? PKDrawing(data: entry.drawingData),
              !drawing.bounds.isEmpty else { return nil }
        return drawing.image(from: drawing.bounds, scale: 1)
    }

    private var title: String {
        if !entry.prompt.isEmpty { return entry.prompt }
        if let text = entry.text, !text.isEmpty { return text }
        return entry.format?.title ?? "Untitled"
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: entry.format?.icon ?? entry.style.icon)
                .font(.subheadline)
                .foregroundStyle(Color.homeAccent)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
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
                    .frame(width: 52, height: 52)
                    .background(Color.homeTint, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.vertical, 4)
    }
}

/// A gentle placeholder for a home surface that isn't built yet (AI companion,
/// Meetings, notifications), styled to match the lavender home.
struct HomeComingSoonView: View {
    let title: String
    let systemImage: String
    let message: String
    var embedInStack = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if embedInStack {
            NavigationStack { content.toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Close") { dismiss() } }
            } }
            .tint(.homeAccent)
        } else {
            content
        }
    }

    private var content: some View {
        VStack(spacing: 18) {
            Spacer()
            ZStack {
                Circle().fill(Color.homeTint).frame(width: 96, height: 96)
                Image(systemName: systemImage)
                    .font(.system(size: 40, weight: .regular))
                    .foregroundStyle(Color.homeAccent)
            }
            Text(title)
                .font(.system(.title2, design: .serif).weight(.semibold))
                .foregroundStyle(Color.homeAccentDeep)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.homeSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Text("Coming soon")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.homeAccent)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Color.homeAccent.opacity(0.12), in: Capsule())
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [.homeBackgroundTop, .homeBackgroundBottom],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
