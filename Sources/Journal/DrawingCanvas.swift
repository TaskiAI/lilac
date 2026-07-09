import SwiftUI
import PencilKit

/// A PencilKit canvas wrapped for SwiftUI. A fixed fountain-pen ink tool, no
/// floating tool picker — the page should feel like paper, not an editor.
/// Accepts Apple Pencil, finger, and pointer input (so it works in the
/// simulator). Reports every stroke change back through `onChange` for autosave.
///
/// The canvas is an infinite-scrolling page: it owns the scroll (one finger
/// draws, two fingers scroll — the native PencilKit split), grows its height as
/// ink reaches the bottom, and renders the ruled paper as a background subview
/// inside its own scroll content so rules stay locked to ink.
struct DrawingCanvas: UIViewRepresentable {
    let initialDrawing: PKDrawing
    var ink: UIColor
    var spacing: CGFloat
    var rule: UIColor
    var margin: UIColor
    /// Height reserved at the top of the scroll content for the SwiftUI header.
    var topInset: CGFloat
    let onChange: (PKDrawing) -> Void
    /// Reports `contentOffset.y` so the header can be translated as the page scrolls.
    let onScroll: (CGFloat) -> Void

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawing = initialDrawing
        canvas.delegate = context.coordinator
        canvas.drawingPolicy = .anyInput
        canvas.isScrollEnabled = true
        canvas.alwaysBounceVertical = true
        canvas.showsVerticalScrollIndicator = false
        canvas.contentInsetAdjustmentBehavior = .never
        canvas.backgroundColor = .clear
        canvas.tool = PKInkingTool(.fountainPen, color: ink, width: 3)

        let ruled = RuledBackgroundView()
        canvas.insertSubview(ruled, at: 0)   // behind the ink

        context.coordinator.canvas = canvas
        context.coordinator.ruled = ruled
        return canvas
    }

    /// Never writes `canvas.drawing` (that would clobber in-progress strokes).
    /// It only re-applies the scroll layout and refreshes the ruled background.
    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        let c = context.coordinator
        c.topInset = topInset
        canvas.contentInset.top = topInset

        c.ruled?.spacing = spacing
        c.ruled?.ruleColor = rule
        c.ruled?.marginColor = margin

        // Seed the page height once bounds are known: at least a viewport,
        // and tall enough to contain an existing drawing plus a screen of room.
        if c.pageHeight == 0, canvas.bounds.height > 0 {
            let inkBottom = initialDrawing.strokes.isEmpty ? 0 : initialDrawing.bounds.maxY
            c.pageHeight = max(canvas.bounds.height, inkBottom + canvas.bounds.height)
        }
        c.applyLayout()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onChange: onChange, onScroll: onScroll)
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        let onChange: (PKDrawing) -> Void
        let onScroll: (CGFloat) -> Void
        weak var canvas: PKCanvasView?
        weak var ruled: RuledBackgroundView?
        var pageHeight: CGFloat = 0
        var topInset: CGFloat = 0

        init(onChange: @escaping (PKDrawing) -> Void, onScroll: @escaping (CGFloat) -> Void) {
            self.onChange = onChange
            self.onScroll = onScroll
        }

        /// Push `pageHeight` into the scroll content size and the ruled background frame.
        func applyLayout() {
            guard let canvas, pageHeight > 0 else { return }
            let width = canvas.bounds.width
            canvas.contentSize = CGSize(width: width, height: pageHeight)
            ruled?.frame = CGRect(x: 0, y: 0, width: width, height: pageHeight)
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            onChange(canvasView.drawing)

            // Grow the page when ink approaches the current bottom.
            guard !canvasView.drawing.strokes.isEmpty else { return }
            let screen = canvasView.bounds.height
            let threshold = screen * 0.25
            let inkBottom = canvasView.drawing.bounds.maxY
            if inkBottom > pageHeight - threshold {
                pageHeight = inkBottom + screen
                applyLayout()
            }
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            onScroll(scrollView.contentOffset.y)
        }
    }
}
