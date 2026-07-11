import SwiftUI
import SwiftData

/// The Journal tab: a reverse-chronological list of typed entries. Tap one to
/// edit, or the compose button to start a new one. Settings live behind the
/// gear.
struct JournalListView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var auth: AuthManager
    @Query(sort: \JournalEntry.createdAt, order: .reverse) private var entries: [JournalEntry]

    @State private var path: [JournalEntry] = []
    @State private var showingSettings = false

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if entries.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(entries) { entry in
                            NavigationLink(value: entry) { EntryRow(entry: entry) }
                        }
                        .onDelete(perform: delete)
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(
                LinearGradient(colors: [.homeBackgroundTop, .homeBackgroundBottom],
                               startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            )
            .navigationTitle("Journal")
            .navigationDestination(for: JournalEntry.self) { JournalEntryView(entry: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingSettings = true } label: {
                        Image(systemName: "person.crop.circle")
                    }
                    .accessibilityLabel("Settings")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: newEntry) {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("New entry")
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView().environmentObject(auth)
            }
        }
        .tint(.homeAccent)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().fill(Color.homeTint).frame(width: 96, height: 96)
                Image(systemName: "book")
                    .font(.system(size: 38))
                    .foregroundStyle(Color.homeAccent)
            }
            Text("Your journal is empty")
                .font(.system(.title2, design: .serif).weight(.semibold))
                .foregroundStyle(Color.homeAccentDeep)
            Text("Write a reflection between sessions — how you're feeling, what came up, what you want to bring next time.")
                .font(.subheadline)
                .foregroundStyle(Color.homeSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
            Button(action: newEntry) {
                Label("New entry", systemImage: "square.and.pencil")
                    .font(.system(.subheadline, design: .serif).weight(.medium))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(Capsule().fill(Color.homeAccent))
                    .foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func newEntry() {
        let entry = JournalEntry()
        context.insert(entry)
        path.append(entry)
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets { context.delete(entries[index]) }
    }
}

private struct EntryRow: View {
    let entry: JournalEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.displayTitle)
                .font(.system(.body, design: .serif).weight(.medium))
                .foregroundStyle(Color.homeHeading)
                .lineLimit(1)
            Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(Color.homeSecondary)
        }
        .padding(.vertical, 4)
    }
}
