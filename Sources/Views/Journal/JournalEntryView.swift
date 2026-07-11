import SwiftUI
import SwiftData

/// The typed journal editor: a title and a free-form body. Edits write straight
/// into the `@Model`, so SwiftData autosaves — there's no explicit save action.
struct JournalEntryView: View {
    @Bindable var entry: JournalEntry

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @FocusState private var bodyFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(entry.createdAt.formatted(date: .complete, time: .shortened))
                    .font(.system(.footnote, design: .serif))
                    .foregroundStyle(Color.homeSecondary)

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
                        .frame(minHeight: 320)
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

    private func deleteEntry() {
        context.delete(entry)
        dismiss()
    }
}
