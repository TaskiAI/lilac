import SwiftUI
import SwiftData
import PencilKit
import PhotosUI

/// The concrete screen for the free-drawing and diagram journal formats — a
/// thin wrapper over `SketchCanvas`, mirroring how `EntryEditorView` wraps the
/// writing `JournalPage`. Blank paper for a drawing, a dot grid for a diagram,
/// and an optional photo laid behind the ink to annotate over (imported or
/// pasted). The drawing is autosaved through `onChange`; the photo lives on the
/// entry as `backgroundImageData`.
struct DrawingJournalView: View {
    @Bindable var entry: JournalEntry
    var theme: JournalTheme = .diary

    @State private var backgroundImage: UIImage?
    @State private var pickerItem: PhotosPickerItem?

    private var background: SketchCanvas.Background {
        entry.format == .diagram ? .dotGrid : .blank
    }

    private var loadedDrawing: PKDrawing {
        (try? PKDrawing(data: entry.drawingData)) ?? PKDrawing()
    }

    var body: some View {
        SketchCanvas(
            initialDrawing: loadedDrawing,
            background: background,
            gridColor: UIColor(theme.rule),
            backgroundImage: backgroundImage,
            onChange: { entry.drawingData = $0.dataRepresentation() }
        )
        .background(theme.paper)
        .ignoresSafeArea(.container, edges: .bottom)
        .navigationTitle(entry.format?.title ?? "Drawing")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(theme.paper, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .tint(theme.ink)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if UIPasteboard.general.hasImages {
                    Button {
                        if let image = UIPasteboard.general.image { setPhoto(image) }
                    } label: {
                        Image(systemName: "doc.on.clipboard")
                    }
                    .accessibilityLabel("Paste photo")
                }
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Image(systemName: backgroundImage == nil ? "photo.badge.plus" : "photo")
                }
                .accessibilityLabel("Add background photo")
            }
        }
        .task { loadPhoto() }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task { @MainActor in
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    setPhoto(image)
                }
            }
        }
    }

    private func loadPhoto() {
        if backgroundImage == nil, let data = entry.backgroundImageData {
            backgroundImage = UIImage(data: data)
        }
    }

    /// Store the chosen/pasted photo as the annotate-over background, downscaled
    /// for compact persistence.
    private func setPhoto(_ image: UIImage) {
        backgroundImage = image
        entry.backgroundImageData = image.journalEncoded()
    }
}
