# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Lilac is an iOS journaling app. Entries are **handwritten** (Apple Pencil / finger) on a ruled, aged-paper page, not typed text. The current mode is a free-form diary; prompted / typed journaling modes will be built on the same reusable page. Built with SwiftUI + SwiftData + PencilKit, iOS 17+.

## Project generation & build

The Xcode project (`Lilac.xcodeproj`) is **generated** from `project.yml` by [XcodeGen](https://github.com/yonaskolb/XcodeGen) — treat the `.xcodeproj` as a build artifact. Edit `project.yml` for any target/setting/bundle-id changes, then regenerate; do not hand-edit `project.pbxproj`.

```sh
xcodegen generate                                    # regenerate .xcodeproj after changing project.yml or adding files
xcodebuild -project Lilac.xcodeproj -scheme Lilac \
  -destination 'platform=iOS Simulator,name=iPhone 17' build   # use any installed simulator (xcrun simctl list devices available)
```

New Swift files under `Sources/` are picked up automatically on the next `xcodegen generate` (the target sources the whole `Sources` directory) — no need to register files manually.

There is no test target and no lint config in the repo yet.

## Architecture

Single-window SwiftUI app. Data flows through SwiftData; there is no separate view-model layer.

- `LilacApp.swift` — `@main`; installs the `.modelContainer(for: JournalEntry.self)` and global `.lilac` tint.
- `Models/JournalEntry.swift` — the only `@Model`. A drawing is persisted as `drawingData: Data`, the serialized `PKDrawing.dataRepresentation()`. There is no separate image storage; thumbnails are rendered on demand.
- `Views/EntryListView.swift` — home screen. Uses `@Query` for the reverse-chronological feed and drives navigation with a `NavigationStack(path:)`. New entries are inserted into the context and pushed onto the path in one step. `EntryRow` renders a live thumbnail by decoding `drawingData` back into a `PKDrawing`.
- `Views/EntryEditorView.swift` — a **concrete screen**, not the surface itself: the free-form diary, which is just `JournalPage(entry:)` with no accessory. New journaling modes are new thin screens like this one.
- `Prompts/PromptBank.swift` — a hardcoded list of curated prompts per style with `random(for:excluding:)`. The offline source of truth: always available, no network or key.
- `Prompts/PromptEngine.swift` — the AI-generated prompt engine. `PromptEngine.shared.prompt(for:excluding:)` (async) asks DeepSeek (OpenAI-compatible Chat Completions API, `deepseek-chat`, raw `URLSession` with a `Bearer` key) for a fresh, style-matched prompt, and **falls back to `PromptBank` on any failure** (no key, offline, non-2xx, decode error) — callers never see an error. The key is read from `DEEPSEEK_API_KEY` (process environment, or the Info.plist value wired through `project.yml`); no key ⇒ offline mode. Call sites seed instantly from `PromptBank` then upgrade to a generated prompt in a `@MainActor` `Task` (`EntryListView.newEntry`, the shuffle button in `EntryEditorView`).
- `Theme.swift` — color tokens: the diary palette (below) plus the legacy `Color.lilac` / `Color.lilacSoft`.

### The reusable journaling engine (`Sources/Journal/`)

This is the modular base every journaling type builds on — keep type-specific logic **out** of it.

- `Journal/JournalPage.swift` — `JournalPage<Accessory: View>`, the whole writing surface: date header → optional `accessory` slot → ruled page + canvas → spacing slider. The **extension points** are the two initializer parameters:
  - `accessory:` — a `@ViewBuilder` slot rendered under the date. A prompted mode passes a prompt banner here; the free diary passes nothing (defaults to `EmptyView`).
  - `theme:` — a `JournalTheme` (defaults to `.diary`) so a mode can restyle paper/ink/rules/spacing without touching the page.
  - Line spacing is local `@State` seeded from `theme.defaultSpacing`; it is **not** persisted per entry yet.
- `Journal/JournalTheme.swift` — `JournalTheme` value type bundling `paper`/`ink`/`rule`/`margin` colors + `spacingRange`/`defaultSpacing`. Add a new `static let` here to define a new mode's look.
- `Journal/RuledPaper.swift` — draws the faint rules + left margin with SwiftUI `Canvas`, parameterized by `spacing` and colors. Purely decorative (`allowsHitTesting(false)`).
- `Journal/DrawingCanvas.swift` — `UIViewRepresentable` wrapper over `PKCanvasView` for the **writing** page: fixed fountain-pen ink (color passed in), no floating tool picker, hosts the ruled background inside its scroll content, auto-grows.
- `Journal/SketchCanvas.swift` — the free-drawing counterpart for the **drawing/diagram** formats: shows the full `PKToolPicker` (pens, eraser, colors), scrolls + auto-grows, and renders an optional dot grid (`GridBackgroundView`) behind the ink. Used by `Views/DrawingJournalView.swift` (blank paper for `.drawing`, dot grid for `.diagram`). Persistence is identical to writing — the drawing is `entry.drawingData`, autosaved via `onChange`; `updateUIView` never writes `canvas.drawing`.
- `Journal/RuledBackgroundView.swift` / `Journal/GridBackgroundView.swift` — non-interactive UIKit backgrounds (ruled lines / dot grid) drawn inside the respective canvas's scroll content so they stay locked to the ink.

`Models/JournalFormat.swift` enumerates the non-writing formats surfaced in the home-screen "Create" gallery (`Views/CreateJournalView.swift`), with an `isAvailable` flag. Live formats are `.drawing`/`.diagram` (→ `DrawingJournalView`), `.photo` (→ `Views/PictureJournalView.swift`, a drag/pinch photo collage), and `.audio` (→ `Views/AudioJournalView.swift`), routed via `JournalEntry.format`; only `.log` still presents `ComingSoonEditor`. Photos persist on the entry: `backgroundImageData` (a single annotate-over photo behind the ink in a drawing/diagram — see `SketchCanvas.backgroundImage`) and `collageData` (JSON-encoded `[CollageItem]`, exposed via `JournalEntry.collageItems`). Imported photos are downscaled + JPEG-encoded via `UIImage.journalEncoded` (`Journal/PhotoSupport.swift`).

Audio journaling (`Sources/Audio/`): `AudioRecorder` records a voice note to a temp `.m4a`, `SpeechTranscriber` turns it into text (prefers on-device recognition), `AudioPlayer` plays clips back. `AudioJournalView` records → optionally transcribes into `entry.text` → keeps the audio as `entry.audioClips` (JSON-encoded `[AudioClip]`) → lets the writer keep typing in a `TextEditor`. Mic + speech usage strings are wired in `project.yml` (`NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`).

## Design system (diary aesthetic)

The look is a **warm, deliberate aged-paper diary** — serif type, no tech/AI/startup colors or vocabulary. Preserve this direction; when adding UI, pull from the tokens rather than inventing new colors or fonts.

- **Color** (`Theme.swift`): `paper` warm ivory `#F6EFE0` (the page), `ink` warm near-black `#332B24` (writing + primary text), `rule` faint sepia (ruled lines/hairlines), `margin` dried lilac (left margin + accent/slider tint — ties to the app name while staying warm). Route new surfaces through a `JournalTheme` instead of hardcoding.
- **Type:** system **serif** (New York) for all chrome — `.font(.system(.largeTitle, design: .serif))` for the hero weekday, italic serif for the date line. Keep serif; avoid the default SF sans for user-facing journal text.
- **Layout:** date anchored top-left as the page's hero; quiet controls docked behind hairline (`rule`) dividers; generous padding (24pt horizontal). Chrome stays understated so the page reads as paper, not an editor.

### Key conventions worth preserving

- **Autosave via closure, not binding.** `DrawingCanvas` reports strokes through an `onChange: (PKDrawing) -> Void` callback; the editor writes the encoded data straight into the `@Model`, so SwiftData persists every stroke. There is no explicit "save" action.
- **`DrawingCanvas.updateUIView` is deliberately empty.** Never push the SwiftUI drawing state back into the live `PKCanvasView` — it would clobber in-progress strokes. The initial drawing is set once in `makeUIView`.
- **`drawingPolicy = .anyInput`** so the canvas works with finger/pointer in the Simulator, not just Apple Pencil.
- Drawings are the source of truth for entry content; when reading/rendering an entry, decode `drawingData` with `try? PKDrawing(data:)` and treat an empty/failed decode as a blank `PKDrawing()`.
