# Infinite scrolling journal page — design

**Date:** 2026-07-09
**Status:** Approved for implementation

## Goal

Let a journal page extend vertically past one screen. Today the writing surface
is a fixed-height, non-scrolling `PKCanvasView`. We want a page that **auto-grows
as the writer reaches the bottom** — a notebook page that never ends — and can be
scrolled back through.

## Decisions (from brainstorming)

1. **Growth model — auto-extend.** The page starts about one screen tall (or tall
   enough to contain an existing entry's ink) and appends another screenful of
   ruled paper whenever ink approaches the current bottom. No hard bottom, no big
   empty canvas up front.
2. **Chrome — header scrolls, slider docked.** The date header + accessory are the
   top of the page and scroll away as you write down; the line-spacing slider stays
   pinned at the bottom, always reachable.
3. **Scroll gesture — two-finger.** Because ink is `.anyInput` (finger draws), the
   `PKCanvasView` itself owns the scroll: one finger draws, two fingers scroll. This
   is standard PencilKit / Apple Notes behavior. (Simulator: Option-drag.)

## Why the canvas must own the scroll

A SwiftUI `ScrollView` wrapping a non-scrolling canvas cannot work: with finger
drawing enabled, a single-finger drag on the paper always draws, so it could never
scroll. `PKCanvasView` is a `UIScrollView` subclass and, when finger drawing is on,
automatically routes single-finger touches to drawing and two-finger touches to
scrolling. So the canvas is the scroller and everything that must scroll with the
ink lives in its content coordinate space.

This means we relax the current invariant "`isScrollEnabled = false` so rules and
ink stay aligned" — but we **preserve the alignment itself** by moving the ruled
paper into the canvas's own (now taller) content space, so rules and ink still share
one coordinate system.

## Architecture

### `DrawingCanvas` (the main change)

- `isScrollEnabled = true`, `drawingPolicy = .anyInput` (unchanged), `bounces`
  vertical only.
- **`pageHeight` (coordinator-owned UIKit state).** Sets
  `canvas.contentSize = CGSize(width: viewWidth, height: pageHeight)`.
  - Initial value: `max(viewport height, existingDrawing.bounds.maxY + one screenful)`
    so a fresh entry is one screen and an existing tall entry opens fully contained.
  - **Auto-grow:** in `canvasViewDrawingDidChange`, if
    `drawing.bounds.maxY > pageHeight - growThreshold`, set
    `pageHeight += screenHeight` and update `contentSize` and the ruled-background
    frame. `growThreshold` ≈ a couple of line-heights.
  - Not persisted — recomputed from the drawing on load, exactly as line spacing is
    not persisted today. **No change to `JournalEntry`.**
- **Ruled background as an internal subview.** The ruled paper is rendered into a
  background view inserted *behind* PencilKit's ink, sized to `pageHeight`, inside
  the scroll content. It reuses the existing `RuledPaper` drawing (hosted via a
  `UIHostingController`/host view, or an equivalent `UIView` drawing the same rules)
  so lines scroll in lockstep with ink. It is non-interactive (`allowsHitTesting`
  false), so it never steals drawing touches.
- **Header space + scroll-away header.** `canvas.contentInset.top = headerHeight`
  reserves room at the top of the content for the header. The canvas reports its
  `contentOffset` back to SwiftUI through a callback (`onScroll`), so `JournalPage`
  can translate the header.
- `updateUIView` still **never touches `canvas.drawing`** (the load-clobber
  invariant holds). It *is* allowed to push the current line `spacing` into the
  ruled background and redraw it — that's background chrome, not the drawing.

### `JournalPage`

- Layout becomes: a `ZStack`/overlay of
  - the `DrawingCanvas` (fills the area between header baseline and slider), and
  - the **header + accessory** as real SwiftUI overlaid at the top, translated
    upward by the reported scroll offset and clipped, so they scroll away with the
    page while their controls (e.g. the prompt shuffle button) stay tappable.
- The **spacing slider stays docked** below, outside the scroll, unchanged.
- Line spacing remains local `@State` seeded from `theme.defaultSpacing`; changing
  it redraws the ruled background via `updateUIView`.
- The `accessory:` and `theme:` extension points are unchanged — a prompted mode
  still passes a banner and its own theme.

### `RuledPaper`

- Drawing logic unchanged (rules + left margin, parameterized by `spacing`). It is
  now driven at `pageHeight` inside the canvas content rather than at viewport
  height. If reused via hosting it needs no change; if a `UIView` twin is cleaner
  for embedding, it mirrors the same `while y < height` loop and colors.

## Data flow

1. Editor opens → `JournalPage` decodes `drawingData` → passes `initialDrawing` to
   `DrawingCanvas`.
2. `DrawingCanvas.makeUIView` sets `pageHeight` from the initial drawing bounds,
   `contentSize`, `contentInset.top`, and installs the ruled background.
3. User writes → `canvasViewDrawingDidChange` → (a) autosave via existing
   `onChange` closure writing `entry.drawingData`; (b) grow `pageHeight` if ink
   nears the bottom.
4. User two-finger scrolls → delegate reports `contentOffset` → `JournalPage`
   translates the header.
5. Spacing slider moves → `updateUIView` redraws the ruled background only.

## Invariants preserved

- **Autosave via closure**, not binding — unchanged.
- **`updateUIView` never writes `canvas.drawing`** — unchanged; it only updates the
  ruled background's spacing.
- **Drawings are the source of truth**; `pageHeight` and spacing are derived/local,
  not persisted. No SwiftData migration.
- Diary aesthetic (paper/ink/rule/margin tokens, serif chrome) — unchanged.

## Out of scope (YAGNI)

- Persisting `pageHeight` or spacing per entry.
- Horizontal growth / paging.
- Shrinking the page when ink is erased (grow-only is fine; a reopened entry
  recomputes a tight height anyway).
- Zoom.

## Risks / things to verify during implementation

- Confirm two-finger scroll actually engages with `.anyInput` + `isScrollEnabled`
  (expected PencilKit behavior) in the simulator via Option-drag.
- Confirm the ruled background subview renders **behind** the ink and does not
  intercept drawing touches.
- Confirm header translation stays smooth and the shuffle button remains tappable
  while partially scrolled.
- Confirm an existing long entry reopens with all ink contained (no clipping at the
  old fixed height).
