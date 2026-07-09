import SwiftUI
import SwiftData
import PencilKit

/// The writing surface: a prompt at the top, an infinite-feeling canvas below.
struct EntryEditorView: View {
    @Bindable var entry: JournalEntry

    private var loadedDrawing: PKDrawing {
        (try? PKDrawing(data: entry.drawingData)) ?? PKDrawing()
    }

    var body: some View {
        VStack(spacing: 0) {
            promptHeader

            DrawingCanvas(initialDrawing: loadedDrawing) { drawing in
                entry.drawingData = drawing.dataRepresentation()
            }
            .background(Color(.systemBackground))
        }
        .navigationTitle(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var promptHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Today's prompt")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.lilac)
                    .textCase(.uppercase)
                Text(entry.prompt)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button {
                entry.prompt = PromptBank.random(excluding: entry.prompt)
            } label: {
                Image(systemName: "shuffle")
                    .font(.title3)
                    .padding(10)
                    .background(Color.lilacSoft, in: Circle())
            }
            .accessibilityLabel("New prompt")
        }
        .padding(20)
        .background(Color.lilacSoft.opacity(0.5))
    }
}
