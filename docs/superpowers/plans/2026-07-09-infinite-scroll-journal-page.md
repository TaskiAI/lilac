# Infinite Scrolling Journal Page Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the journal writing surface a page that auto-grows past one screen and scrolls, with the date header scrolling away and the spacing slider docked.

**Architecture:** The `PKCanvasView` itself becomes the scroller (`isScrollEnabled = true`), because with `.anyInput` one finger draws and two fingers scroll natively. The ruled paper moves into the canvas's scroll content as a non-interactive background subview so rules stay pixel-locked to ink in the taller space. Page height auto-grows in the canvas delegate when ink nears the bottom. The header + accessory stay real SwiftUI overlaid on top (so the shuffle button stays tappable), translated by the reported scroll offset.

**Tech Stack:** SwiftUI, PencilKit, SwiftData, XcodeGen. iOS 17+.

## Global Constraints

- iOS 17+, SwiftUI + PencilKit + SwiftData; no view-model layer.
- No test target exists — verification is `xcodebuild` build + run in the iPhone 17 simulator and observe behavior.
- New Swift files under `Sources/` require `xcodegen generate` before building.
- **Do not touch `JournalEntry`** — page height and spacing stay derived/local, never persisted. No SwiftData migration.
- Preserve invariants: autosave via the `onChange` closure; `updateUIView` must NEVER write `canvas.drawing`; drawings are the source of truth.
- Preserve the diary aesthetic — pull colors from the `JournalTheme` tokens; keep serif chrome.
- Build command:
  ```sh
  xcodebuild -project Lilac.xcodeproj -scheme Lilac \
    -destination 'platform=iOS Simulator,name=iPhone 17' build
  ```

---

### Task 1: `RuledBackgroundView` — a UIKit twin of `RuledPaper` for embedding in the scroll content

**Files:**
- Create: `Sources/Journal/RuledBackgroundView.swift`

**Interfaces:**
- Produces: `final class RuledBackgroundView: UIView` with mutable `var spacing: CGFloat`, `var ruleColor: UIColor`, `var marginColor: UIColor`, `var topInset: CGFloat` (default 12), `var marginX: CGFloat` (default 32). Setting any triggers `setNeedsDisplay()`. Draws faint horizontal rules every `spacing` points plus a left margin line, mirroring `RuledPaper`.

**Why a UIView twin, not the SwiftUI `RuledPaper`:** it must live *inside* the `PKCanvasView`'s scroll content so it scrolls in perfect lockstep with the ink. Hosting a SwiftUI view inside a `UIScrollView`'s content is heavier and more fragile than a ~15-line `draw(_:)`. Small, intentional duplication of the rule-drawing loop.

- [ ] **Step 1: Write the view**

```swift
import UIKit

/// UIKit twin of `RuledPaper`, drawn *inside* the scrolling `PKCanvasView`'s
/// content so the rules scroll in lockstep with the ink. Non-interactive.
final class RuledBackgroundView: UIView {
    var spacing: CGFloat = 34 { didSet { setNeedsDisplay() } }
    var ruleColor: UIColor = .gray { didSet { setNeedsDisplay() } }
    var marginColor: UIColor = .purple { didSet { setNeedsDisplay() } }
    var topInset: CGFloat = 12 { didSet { setNeedsDisplay() } }
    var marginX: CGFloat = 32 { didSet { setNeedsDisplay() } }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
        contentMode = .redraw
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext(), spacing > 0 else { return }

        ctx.setLineWidth(0.75)
        ctx.setStrokeColor(ruleColor.cgColor)
        var y = topInset + spacing
        while y < bounds.height {
            ctx.move(to: CGPoint(x: 0, y: y))
            ctx.addLine(to: CGPoint(x: bounds.width, y: y))
            ctx.strokePath()
            y += spacing
        }

        ctx.setLineWidth(1)
        ctx.setStrokeColor(marginColor.withAlphaComponent(0.35).cgColor)
        ctx.move(to: CGPoint(x: marginX, y: 0))
        ctx.addLine(to: CGPoint(x: marginX, y: bounds.height))
        ctx.strokePath()
    }
}
```

- [ ] **Step 2: Regenerate the project so the new file is in the target**

Run: `xcodegen generate`
Expected: `Created project at .../Lilac.xcodeproj`

- [ ] **Step 3: Build to confirm it compiles**

Run:
```sh
xcodebuild -project Lilac.xcodeproj -scheme Lilac \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add Sources/Journal/RuledBackgroundView.swift project.yml Lilac.xcodeproj
git commit -m "Add RuledBackgroundView: UIKit ruled paper for the scrolling canvas"
```

---

### Task 2: Make `DrawingCanvas` scroll, grow, host the ruled background, and report scroll offset

**Files:**
- Modify: `Sources/Journal/DrawingCanvas.swift`

**Interfaces:**
- Consumes: `RuledBackgroundView` (Task 1).
- Produces: updated `DrawingCanvas` initialized as
  `DrawingCanvas(initialDrawing:ink:spacing:rule:margin:topInset:onChange:onScroll:)` where
  `spacing: CGFloat`, `rule: UIColor`, `margin: UIColor`, `topInset: CGFloat`,
  `onChange: (PKDrawing) -> Void`, `onScroll: (CGFloat) -> Void` (reports `contentOffset.y`).

**Behavior:** `isScrollEnabled = true`; the canvas owns a `pageHeight` that starts at ≥ one viewport (tall enough to contain an existing drawing) and grows by a screenful whenever `drawing.bounds.maxY` comes within a threshold of the bottom. A `RuledBackgroundView` is inserted behind the ink at `pageHeight`. `contentInset.top = topInset` reserves the header band. `updateUIView` re-applies layout + spacing but never writes `canvas.drawing`.

- [ ] **Step 1: Replace the file contents**

```swift
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
```

- [ ] **Step 2: Build (will fail — `JournalPage` still uses the old initializer)**

Run:
```sh
xcodebuild -project Lilac.xcodeproj -scheme Lilac \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```
Expected: FAIL — errors in `JournalPage.swift` about missing arguments `spacing`/`rule`/`margin`/`topInset`/`onScroll`. (This confirms the new API; Task 3 fixes the call site.)

- [ ] **Step 3: Commit**

```bash
git add Sources/Journal/DrawingCanvas.swift
git commit -m "DrawingCanvas: own the scroll, auto-grow page height, host ruled background"
```

---

### Task 3: Rework `JournalPage` — header overlay that scrolls away, wire the new canvas

**Files:**
- Modify: `Sources/Journal/JournalPage.swift`

**Interfaces:**
- Consumes: `DrawingCanvas(initialDrawing:ink:spacing:rule:margin:topInset:onChange:onScroll:)` (Task 2).

**Behavior:** The header + accessory become a SwiftUI overlay on top of the canvas (so the shuffle button stays tappable), with an opaque paper background. Its measured height is fed to the canvas as `topInset`; the canvas's reported scroll offset translates the header up so it scrolls away. The `RuledPaper` sibling is removed from this screen (rules now live inside the canvas). The spacing slider stays docked below.

- [ ] **Step 1: Replace the file contents**

```swift
import SwiftUI
import SwiftData
import PencilKit

/// The reusable writing surface every journaling type is built on: the day's
/// date, an optional `accessory` (a prompt, a mood, anything a type adds above
/// the page), a ruled page you write on, and a slider that tightens the lines.
///
/// The page scrolls: it grows as you write to the bottom (one finger draws, two
/// fingers scroll), the header scrolls away with the page, and the spacing
/// slider stays docked.
///
/// The free-form diary is just `JournalPage(entry:)`. A future prompted type
/// passes an `accessory` — and its own `theme` if it wants a different look:
///
///     JournalPage(entry: entry) {
///         PromptBanner(text: entry.prompt)
///     }
struct JournalPage<Accessory: View>: View {
    @Bindable var entry: JournalEntry
    var theme: JournalTheme
    @ViewBuilder var accessory: () -> Accessory

    @State private var lineSpacing: CGFloat
    @State private var headerHeight: CGFloat = 0
    @State private var scrollOffset: CGFloat = 0

    init(
        entry: JournalEntry,
        theme: JournalTheme = .diary,
        @ViewBuilder accessory: @escaping () -> Accessory = { EmptyView() }
    ) {
        self.entry = entry
        self.theme = theme
        self.accessory = accessory
        _lineSpacing = State(initialValue: theme.defaultSpacing)
    }

    private var loadedDrawing: PKDrawing {
        (try? PKDrawing(data: entry.drawingData)) ?? PKDrawing()
    }

    /// Header translation: 0 at rest (canvas is inset by the header height),
    /// sliding up to `-headerHeight` as the page scrolls. Clamped so it never
    /// drifts down past the top during rubber-band overscroll.
    private var headerTranslation: CGFloat {
        min(0, -(scrollOffset + headerHeight))
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                DrawingCanvas(
                    initialDrawing: loadedDrawing,
                    ink: UIColor(theme.ink),
                    spacing: lineSpacing,
                    rule: UIColor(theme.rule),
                    margin: UIColor(theme.margin),
                    topInset: headerHeight,
                    onChange: { entry.drawingData = $0.dataRepresentation() },
                    onScroll: { scrollOffset = $0 }
                )

                header
                    .background(theme.paper)
                    .offset(y: headerTranslation)
            }

            spacingControl
        }
        .background(theme.paper)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(theme.paper, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .tint(theme.ink)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.createdAt.formatted(.dateTime.weekday(.wide)))
                    .font(.system(.largeTitle, design: .serif))
                    .foregroundStyle(theme.ink)
                Text(entry.createdAt.formatted(.dateTime.day().month(.wide).year()))
                    .font(.system(.subheadline, design: .serif).italic())
                    .foregroundStyle(theme.ink.opacity(0.55))
            }
            accessory()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 18)
        .background(
            GeometryReader { proxy in
                Color.clear.preference(key: HeaderHeightKey.self, value: proxy.size.height)
            }
        )
        .onPreferenceChange(HeaderHeightKey.self) { headerHeight = $0 }
    }

    private var spacingControl: some View {
        HStack(spacing: 16) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 10))
                .foregroundStyle(theme.ink.opacity(0.4))
            Slider(value: $lineSpacing, in: theme.spacingRange)
                .tint(theme.margin)
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 18))
                .foregroundStyle(theme.ink.opacity(0.4))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(theme.paper)
        .overlay(alignment: .top) {
            Rectangle().fill(theme.rule).frame(height: 0.75)
        }
    }
}

/// Carries the measured header height up so the canvas can reserve that much
/// top inset and the header can be translated as the page scrolls.
private struct HeaderHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
```

- [ ] **Step 2: Regenerate + build**

Run:
```sh
xcodegen generate && xcodebuild -project Lilac.xcodeproj -scheme Lilac \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add Sources/Journal/JournalPage.swift Lilac.xcodeproj
git commit -m "JournalPage: scrolling page with header that scrolls away, docked slider"
```

---

### Task 4: Verify in the simulator

**Files:** none (verification only).

- [ ] **Step 1: Boot the simulator and install/run**

Run:
```sh
xcrun simctl boot "iPhone 17" 2>/dev/null; open -a Simulator
xcodebuild -project Lilac.xcodeproj -scheme Lilac \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath /private/tmp/claude-501/-Users-arda-Projects-lilac/9479f9f0-1cdf-470a-a28e-73d9c6f2b6d1/scratchpad/DD build
xcrun simctl install "iPhone 17" \
  /private/tmp/claude-501/-Users-arda-Projects-lilac/9479f9f0-1cdf-470a-a28e-73d9c6f2b6d1/scratchpad/DD/Build/Products/Debug-iphonesimulator/Lilac.app
xcrun simctl launch "iPhone 17" $(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' /private/tmp/claude-501/-Users-arda-Projects-lilac/9479f9f0-1cdf-470a-a28e-73d9c6f2b6d1/scratchpad/DD/Build/Products/Debug-iphonesimulator/Lilac.app/Info.plist)
```
Expected: app launches to the entry list.

- [ ] **Step 2: Create an entry and verify behaviors** (drag with mouse = draw; Option-drag = two-finger scroll)

Confirm each:
- Drawing with a single drag lays down ink; the ruled lines sit behind the ink and stay aligned.
- Writing down near the bottom of the screen auto-extends the page (Option-drag scrolls to reveal fresh ruled paper below your ink).
- Two-finger (Option-drag) scroll moves the page; the **date header scrolls up and away**; scrolling back reveals it.
- The **spacing slider stays docked** at the bottom while scrolling, and moving it still re-tightens the ruled lines.
- If using a prompted screen, the **shuffle button is still tappable** while the header is at rest.

- [ ] **Step 3: Verify an existing entry reopens fully contained**

Reopen the entry created above (navigate back to the list, tap it). Confirm all previously drawn ink is present and the page is scrollable to reach it — nothing clipped at the old fixed height.

- [ ] **Step 4 (if any check fails):** invoke `superpowers:systematic-debugging`; do not paper over. Otherwise proceed to push.

---

### Task 5: Push

- [ ] **Step 1: Confirm clean tree and push**

```bash
git status
git push
```
Expected: all task commits pushed to `origin/main`.
