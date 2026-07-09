import SwiftUI
import PencilKit

/// A PencilKit canvas wrapped for SwiftUI. Accepts Apple Pencil, finger, and
/// pointer input (so it works in the simulator). Reports every stroke change
/// back through `onChange` for autosave.
struct DrawingCanvas: UIViewRepresentable {
    let initialDrawing: PKDrawing
    let onChange: (PKDrawing) -> Void

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawing = initialDrawing
        canvas.delegate = context.coordinator
        canvas.drawingPolicy = .anyInput
        canvas.alwaysBounceVertical = true
        canvas.backgroundColor = .clear

        let picker = context.coordinator.toolPicker
        picker.setVisible(true, forFirstResponder: canvas)
        picker.addObserver(canvas)
        DispatchQueue.main.async {
            canvas.becomeFirstResponder()
        }
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
        let toolPicker = PKToolPicker()
        let onChange: (PKDrawing) -> Void

        init(onChange: @escaping (PKDrawing) -> Void) {
            self.onChange = onChange
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            onChange(canvasView.drawing)
        }
    }
}
