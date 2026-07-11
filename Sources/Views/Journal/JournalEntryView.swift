import SwiftUI
import SwiftData

/// The typed journal editor: an optional therapy-aware prompt, a title, and a
/// free-form body. When it reflects on a session, a chip links back to it. Edits
/// write straight into the `@Model`, so SwiftData autosaves.
struct JournalEntryView: View {
    @Bindable var entry: JournalEntry
    /// True when presented as a sheet (adds a Done button); false when pushed.
    var showsDone = false

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @FocusState private var bodyFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(entry.createdAt.formatted(date: .complete, time: .shortened))
                    .font(.system(.footnote, design: .serif))
                    .foregroundStyle(Color.homeSecondary)

                if let session = entry.linkedSession {
                    sessionChip(session)
                }

                if !entry.prompt.isEmpty {
                    promptBanner
                }

                TextField("Title", text: $entry.title)
                    .font(.system(.title2, design: .serif).weight(.semibold))
                    .foregroundStyle(Color.homeHeading)

                Divider().overlay(Color.homeHairline)

                ZStack(alignment: .topLeading) {
                    if entry.text.isEmpty {
                        Text("Write what's on your mind…")
                            .font(.system(.body, design: .serif))
                            .foregroundStyle(Color.homeSecondary.opacity(0.6))
                            .padding(.top, 8)
                            .padding(.leading, 5)
                    }
                    TextEditor(text: $entry.text)
                        .font(.system(.body, design: .serif))
                        .foregroundStyle(Color.homeHeading)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 300)
                        .focused($bodyFocused)
                }
            }
            .padding(20)
        }
        .background(
            LinearGradient(colors: [.homeBackgroundTop, .homeBackgroundBottom],
                           startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
        )
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsDone {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(role: .destructive, action: deleteEntry) {
                        Label("Delete entry", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .tint(.homeAccent)
    }

    private var promptBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "quote.opening")
                .font(.footnote)
                .foregroundStyle(Color.homeAccent)
            Text(entry.prompt)
                .font(.system(.subheadline, design: .serif).italic())
                .foregroundStyle(Color.homeAccentDeep)
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.homeTint))
    }

    private func sessionChip(_ session: TherapySession) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "waveform")
                .font(.caption2)
            Text("Reflecting on \(session.title.isEmpty ? "your session" : session.title) · \(session.date.formatted(date: .abbreviated, time: .omitted))")
                .font(.caption2)
                .lineLimit(1)
        }
        .foregroundStyle(Color.homeAccent)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.homeTint))
    }

    private func deleteEntry() {
        context.delete(entry)
        dismiss()
    }
}
