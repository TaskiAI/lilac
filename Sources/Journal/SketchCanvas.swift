import SwiftUI
import PencilKit

/// A free-drawing PencilKit surface for the drawing and diagram journals — the
/// counterpart to the writing page's `DrawingCanvas`. Where the writing canvas
/// is locked to a single fountain pen with no picker (it should feel like paper),
/// this shows the full `PKToolPicker` — pen, pencil, marker, eraser, and the
/// color palette — so the page is a real sketchpad.
///
/// Like the writing page it owns the scroll (one finger draws, two fingers
/// scroll) and auto-grows as ink reaches the bottom. For diagrams it renders a
/// dot grid behind the ink as an internal subview so the lattice stays locked to
/// the drawing. `updateUIView` never writes `canvas.drawing`.
struct SketchCanvas: UIViewRepresentable {
    enum Background { case blank, dotGrid }

    let initialDrawing: PKDrawing
    var background: Background
    var gridColor: UIColor
    /// An optional photo laid behind the ink to annotate over. Pinned to the top
    /// of the page at full content width; the page grows to contain it.
    var backgroundImage: UIImage?
    let onChange: (PKDrawing) -> Void

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawing = initialDrawing
        canvas.delegate = context.coordinator
        canvas.drawingPolicy = .anyInput
        canvas.alwaysBounceVertical = true
        canvas.showsVerticalScrollIndicator = false
        canvas.contentInsetAdjustmentBehavior = .never
        canvas.backgroundColor = .clear
        canvas.tool = PKInkingTool(.pen, color: .label, width: 4)

        if background == .dotGrid {
            let grid = GridBackgroundView()
            grid.dotColor = gridColor
            canvas.insertSubview(grid, at: 0)   // behind the ink
            context.coordinator.grid = grid
        }

        // The system tool picker: pens, eraser, colors. Docks at the bottom on
        // iPhone. Requires the canvas to be first responder.
        let picker = PKToolPicker()
        picker.setVisible(true, forFirstResponder: canvas)
        picker.addObserver(canvas)
        context.coordinator.toolPicker = picker
        DispatchQueue.main.async { canvas.becomeFirstResponder() }

        context.coordinator.canvas = canvas
        return canvas
    }

    /// Never writes `canvas.drawing` (that would clobber in-progress strokes).
    /// It only seeds and re-applies the scroll layout / grid frame.
    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        let c = context.coordinator
        guard canvas.bounds.width > 0 else { return }
        if c.pageHeight == 0 {
            let inkBottom = initialDrawing.strokes.isEmpty ? 0 : initialDrawing.bounds.maxY
            c.pageHeight = max(canvas.bounds.height * 2, inkBottom + canvas.bounds.height)
        }
        c.setBackgroundImage(backgroundImage)
        c.applyLayout()
    }

    func makeCoordinator() -> Coordinator { Coordinator(onChange: onChange) }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        let onChange: (PKDrawing) -> Void
        weak var canvas: PKCanvasView?
        weak var grid: GridBackgroundView?
        weak var photo: UIImageView?
        var toolPicker: PKToolPicker?
        var pageHeight: CGFloat = 0

        init(onChange: @escaping (PKDrawing) -> Void) { self.onChange = onChange }

        /// Install, update, or remove the annotate-over background photo. Kept
        /// behind the ink (and behind the grid) so strokes land on top.
        func setBackgroundImage(_ image: UIImage?) {
            guard let canvas else { return }
            if let image {
                if photo == nil {
                    let iv = UIImageView()
                    iv.contentMode = .scaleAspectFit
                    iv.isUserInteractionEnabled = false
                    canvas.insertSubview(iv, at: 0)   // below grid + ink
                    photo = iv
                }
                if photo?.image !== image { photo?.image = image }
                // Make sure the page is tall enough to show the whole photo.
                if let img = photo?.image, img.size.width > 0, canvas.bounds.width > 0 {
                    let h = canvas.bounds.width * img.size.height / img.size.width
                    pageHeight = max(pageHeight, h + canvas.bounds.height * 0.5)
                }
            } else {
                photo?.removeFromSuperview()
                photo = nil
            }
        }

        /// Push `pageHeight` into the scroll content size, the grid frame, and the
        /// photo frame (top-anchored, full width, aspect height).
        func applyLayout() {
            guard let canvas, pageHeight > 0 else { return }
            let width = canvas.bounds.width
            canvas.contentSize = CGSize(width: width, height: pageHeight)
            grid?.frame = CGRect(x: 0, y: 0, width: width, height: pageHeight)
            if let iv = photo, let img = iv.image, img.size.width > 0 {
                iv.frame = CGRect(x: 0, y: 0, width: width, height: width * img.size.height / img.size.width)
            }
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            onChange(canvasView.drawing)

            // Grow the page when ink approaches the current bottom.
            guard !canvasView.drawing.strokes.isEmpty else { return }
            let screen = canvasView.bounds.height
            let bottom = canvasView.drawing.bounds.maxY
            if bottom > pageHeight - screen * 0.5 {
                pageHeight = bottom + screen
                applyLayout()
            }
        }
    }
}
