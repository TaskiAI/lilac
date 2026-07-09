import SwiftUI
import PencilKit

/// A PencilKit canvas wrapped for SwiftUI. A fixed fountain-pen ink tool, no
/// floating tool picker — the page should feel like paper, not an editor.
/// Accepts Apple Pencil, finger, and pointer input (so it works in the
/// simulator). Reports every stroke change back through `onChange` for autosave.
struct DrawingCanvas: UIViewRepresentable {
    let initialDrawing: PKDrawing
    var ink: UIColor
    let onChange: (PKDrawing) -> Void

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawing = initialDrawing
        canvas.delegate = context.coordinator
        canvas.drawingPolicy = .anyInput
        canvas.isScrollEnabled = false
        canvas.backgroundColor = .clear
        canvas.tool = PKInkingTool(.fountainPen, color: ink, width: 3)
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        // Intentionally empty: never overwrite the live drawing from SwiftUI,
        // it would clobber in-progress strokes.
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onChange: onChange)
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        let onChange: (PKDrawing) -> Void

        init(onChange: @escaping (PKDrawing) -> Void) {
            self.onChange = onChange
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            onChange(canvasView.drawing)
        }
    }
}
