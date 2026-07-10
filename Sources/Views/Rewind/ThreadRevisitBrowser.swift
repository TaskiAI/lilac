import SwiftUI
import PencilKit

/// User-initiated theme browsing (not the passive surfacing flow): pick a theme
/// and read every matching entry in order, to see a thread across time. Also
/// hosts the opt-in "revisit hardest weeks" mode, which is gated behind an
/// explicit confirmation because it shows crisis-flagged content.
struct ThreadRevisitBrowser: View {
    let engine: RewindEngine

    @Environment(\.dismiss) private var dismiss
    @State private var themes: [String] = []
    @State private var selectedTheme: String?
    @State private var entries: [JournalEntry] = []

    @State private var confirmHardest = false
    @State private var showingHardest = false

    var body: some View {
        NavigationStack {
            List {
                if showingHardest {
                    hardestHeader
                } else {
                    themePicker
                }

                Section {
                    ForEach(entries) { entry in
                        ThreadEntryRow(entry: entry)
                    }
                    if entries.isEmpty {
                        Text(showingHardest ? "No entries here." : "Pick a theme to see its thread.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Revisit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task { themes = engine.allThemes() }
            .confirmationDialog(
                "Revisit hardest weeks?",
                isPresented: $confirmHardest,
                titleVisibility: .visible
            ) {
                Button("Show these entries") {
                    entries = engine.hardestWeeks()
                    selectedTheme = nil
                    showingHardest = true
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This shows entries from your most difficult times. Only continue if you're ready.")
            }
        }
    }

    private var themePicker: some View {
        Section {
            if themes.isEmpty {
                Text("No themes yet — they appear as you journal.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(themes, id: \.self) { theme in
                            Button {
                                selectedTheme = theme
                                entries = engine.entries(forTheme: theme)
                            } label: {
                                Text(theme.replacingOccurrences(of: "-", with: " "))
                                    .font(.caption.weight(.medium))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        selectedTheme == theme ? Color.lilac : Color.lilac.opacity(0.12),
                                        in: Capsule()
                                    )
                                    .foregroundStyle(selectedTheme == theme ? .white : Color.lilac)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            Button(role: .destructive) {
                confirmHardest = true
            } label: {
                Label("Revisit hardest weeks", systemImage: "heart.slash")
            }
        }
    }

    private var hardestHeader: some View {
        Section {
            Button {
                showingHardest = false
                entries = selectedTheme.map { engine.entries(forTheme: $0) } ?? []
            } label: {
                Label("Back to themes", systemImage: "chevron.left")
            }
        }
    }
}

private struct ThreadEntryRow: View {
    let entry: JournalEntry

    private var thumbnail: UIImage? {
        guard let drawing = try? PKDrawing(data: entry.drawingData),
              !drawing.bounds.isEmpty else { return nil }
        return drawing.image(from: drawing.bounds, scale: 1)
    }

    private var snippet: String {
        if let text = entry.text, !text.isEmpty { return text }
        if !entry.prompt.isEmpty { return entry.prompt }
        return entry.format?.title ?? "Entry"
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.createdAt.formatted(.dateTime.month().day().year()))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(snippet)
                    .font(.subheadline)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                    .background(Color.lilacSoft, in: RoundedRectangle(cornerRadius: 6))
            }
        }
    }
}
