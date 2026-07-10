import SwiftUI
import PencilKit

/// The reflection surface: the original entry ("Then") beside a composer for
/// today's reflection ("Now"). Stacked on iPhone. Saving links the new entry
/// back to the original via `RewindEngine.reflect`.
struct ThenNowView: View {
    let source: JournalEntry
    let engine: RewindEngine

    @Environment(\.dismiss) private var dismiss
    @State private var reflection = ""

    private var thumbnail: UIImage? {
        guard let drawing = try? PKDrawing(data: source.drawingData),
              !drawing.bounds.isEmpty else { return nil }
        return drawing.image(from: drawing.bounds, scale: 1)
    }

    private var snippet: String {
        if let text = source.text, !text.isEmpty { return text }
        if !source.prompt.isEmpty { return source.prompt }
        return source.format?.title ?? "A past entry"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    then
                    Divider()
                    now
                }
                .padding(20)
            }
            .navigationTitle("Then & Now")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(reflection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private var then: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Then · \(source.createdAt.formatted(.dateTime.month(.wide).day().year()))")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.lilac)
                .textCase(.uppercase)
            HStack(alignment: .top, spacing: 12) {
                Text(snippet)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 64, height: 64)
                        .background(Color.lilacSoft, in: RoundedRectangle(cornerRadius: 8))
                }
            }
            if !source.themeTags.isEmpty {
                ThemeTagRow(tags: source.themeTags)
            }
        }
    }

    private var now: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Now")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.lilac)
                .textCase(.uppercase)
            ZStack(alignment: .topLeading) {
                if reflection.isEmpty {
                    Text("What's different now? What's the same?")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                }
                TextEditor(text: $reflection)
                    .frame(minHeight: 200)
                    .scrollContentBackground(.hidden)
            }
        }
    }

    private func save() {
        engine.reflect(on: source, text: reflection.trimmingCharacters(in: .whitespacesAndNewlines))
        dismiss()
    }
}
