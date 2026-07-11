import SwiftUI
import SwiftData

/// The Journal tab: a reverse-chronological list of typed entries, with a
/// therapy-aware nudge to reflect on your most recent session at the top. Tap an
/// entry to edit, or compose a blank one. Settings live behind the gear.
struct JournalListView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var auth: AuthManager
    @Query(sort: \JournalEntry.createdAt, order: .reverse) private var entries: [JournalEntry]
    @Query(sort: \TherapySession.date, order: .reverse) private var sessions: [TherapySession]

    @State private var path: [JournalEntry] = []
    @State private var showingSettings = false
    @State private var generating = false

    private let journalAI = JournalAI()

    /// The most recent recorded, summarized session that hasn't been reflected on yet.
    private var sessionToReflect: TherapySession? {
        sessions.first { session in
            session.hasRecording
                && session.state == .ready
                && (session.summary?.isEmpty == false)
                && !entries.contains { $0.linkedSession?.persistentModelID == session.persistentModelID }
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if entries.isEmpty && sessionToReflect == nil {
                    emptyState
                } else {
                    List {
                        if let session = sessionToReflect {
                            Section {
                                ReflectCard(session: session, generating: generating) {
                                    reflect(on: session)
                                }
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                            }
                        }
                        if !entries.isEmpty {
                            Section("Entries") {
                                ForEach(entries) { entry in
                                    NavigationLink(value: entry) { EntryRow(entry: entry) }
                                }
                                .onDelete(perform: delete)
                            }
                        }
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

    // MARK: Actions

    private func newEntry() {
        let entry = JournalEntry()
        context.insert(entry)
        path.append(entry)
    }

    /// Generate a therapy-aware prompt for the session, create a linked entry, open it.
    private func reflect(on session: TherapySession) {
        guard !generating else { return }
        generating = true
        Task { @MainActor in
            let prompt = await journalAI.reflectionPrompt(for: session)
            let entry = JournalEntry(prompt: prompt, linkedSession: session)
            context.insert(entry)
            generating = false
            path.append(entry)
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets { context.delete(entries[index]) }
    }
}

// MARK: - Reflect card

private struct ReflectCard: View {
    let session: TherapySession
    let generating: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.homeTint).frame(width: 44, height: 44)
                    Image(systemName: "sparkles").foregroundStyle(Color.homeAccent)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Reflect on your last session")
                        .font(.system(.subheadline, design: .serif).weight(.medium))
                        .foregroundStyle(Color.homeHeading)
                    Text(session.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(Color.homeSecondary)
                }
                Spacer(minLength: 4)
                if generating {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.homeSecondary.opacity(0.5))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .homeCardBackground()
        }
        .buttonStyle(.plain)
        .disabled(generating)
        .padding(.vertical, 4)
    }
}

private struct EntryRow: View {
    let entry: JournalEntry

    var body: some View {
        HStack(spacing: 10) {
            if entry.linkedSession != nil {
                Image(systemName: "waveform")
                    .font(.caption)
                    .foregroundStyle(Color.homeAccent)
                    .frame(width: 16)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.displayTitle)
                    .font(.system(.body, design: .serif).weight(.medium))
                    .foregroundStyle(Color.homeHeading)
                    .lineLimit(1)
                Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(Color.homeSecondary)
            }
        }
        .padding(.vertical, 4)
    }
}
