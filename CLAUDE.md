# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Lilac (v2) is a lean **therapy companion** for iOS: record your therapy sessions and reflect between them. It has exactly two features behind an app lock:

1. **Sessions** — record a therapy session → get a speaker-diarized transcript → an AI summary → transcript-grounded Q&A.
2. **Journal** — a simple **typed** journal for reflecting between sessions.

Built with SwiftUI + SwiftData, iOS 17+. No handwriting, no separate view-model layer.

> **History:** v1 was a feature-heavy handwritten-journaling app (5 media formats, AI prompts, an AI companion, an Insights dashboard, the "Rewind" activity, mood logging, etc.). v2 stripped all of that to sharpen the therapy-companion wedge. The full v1 is preserved at git tag **`v1.0`** / branch **`v1-full-featured`**. If you find a reference to a cut feature, it belongs to v1.

## Project generation & build

The Xcode project (`Lilac.xcodeproj`) is **generated** from `project.yml` by [XcodeGen](https://github.com/yonaskolb/XcodeGen) — treat the `.xcodeproj` as a build artifact. Edit `project.yml` for target/setting/bundle-id changes, then regenerate; never hand-edit `project.pbxproj`.

```sh
xcodegen generate
xcodebuild -project Lilac.xcodeproj -scheme Lilac \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

New Swift files under `Sources/` are picked up automatically on the next `xcodegen generate` (the target sources the whole `Sources` directory).

CI (`.github/workflows/ci.yml`) builds + runs the `LilacTests` target on every push/PR to `main`. **This is the primary build verification** — much of v2 was written in an environment that can't compile iOS, so lean on CI.

The `Podfile` still lists optional pods (GoogleSignIn for social auth; ML Kit is now unused after v2). They are not needed to build — the app builds without `pod install` (CI does not run pods). Social sign-in is guarded by `#if canImport(GoogleSignIn)`.

## Architecture

Single-window SwiftUI app; data flows through SwiftData.

- `LilacApp.swift` — `@main`. Container holds just `JournalEntry` + `TherapySession`. `RootView` gates on `AuthManager` (splash → account → lock → app) and, once unlocked, shows `RootTabView` and resumes any pending session transcription (`SessionProcessor.runPending()`).
- `Views/EntryListView.swift` — defines `RootTabView`, the two-tab shell (Journal · Sessions).
- **Two `@Model`s:** `Models/JournalEntry.swift` (typed: `createdAt`/`title`/`text` + `displayTitle`) and `Models/TherapySession.swift` (below). Both must stay registered in `LilacApp`'s container.
- `Theme.swift` — color tokens (the lavender `home*` palette used everywhere; plus legacy `Color.lilac`).
- `Auth/` + `Views/Auth/` — account creation, passcode/biometric app lock (`AuthManager`, `Keychain`, native Sign in with Apple, optional Google). Protects sensitive content.

### Journal (`Views/Journal/`)

- `JournalListView` — reverse-chronological list of typed entries; compose button; settings behind the gear.
- `JournalEntryView` — the typed editor (title + `TextEditor` body). Edits write straight into the `@Model`, so SwiftData autosaves — no explicit save action.

### Sessions — therapist-session assistant (`Sources/Sessions/` + `Sources/Views/Sessions/`)

- **Model:** `TherapySession` — covers a **scheduled** future session (calendar) and a **recorded** one. Audio lives **on disk** (`SessionAudioStore`, Application Support) since sessions run long; the model keeps only `audioFilename`. Diarized utterances (`SessionSegment`), the per-session Q&A (`SessionChatMessage`), and lifecycle (`SessionState`: scheduled/transcribing/ready/failed) are JSON-encoded properties.
- **`DiarizationClient`** — cloud speaker-diarization via **AssemblyAI** (upload → `speaker_labels` → poll → utterances). Optional: `ASSEMBLYAI_API_KEY` (env → Info.plist via `project.yml`); without it, falls back to the on-device `SpeechTranscriber` (flat, unlabeled — and `SFSpeechRecognizer` won't handle a long session, so the key is effectively required for real use). **Sends session audio off-device.**
- **`SessionProcessor`** (`@MainActor`) — record → transcribe (diarize, else on-device) → summarize. Static `inFlight` set prevents double-processing; requests speech authorization before the on-device fallback. Triggered after recording, from the detail screen's `.task`, and on launch via `runPending()`.
- **`SessionAI`** — summary + grounded Q&A through the shared `DeepSeekClient` (`Sources/Prompts/DeepSeekClient.swift`, `deepseek-chat`, `DEEPSEEK_API_KEY`); fails gracefully.
- **Audio (`Sources/Audio/`):** `AudioRecorder`, `AudioPlayer` (on-disk file playback via `play(url:id:)`), `SpeechTranscriber` (on-device fallback).
- **Views:** `SessionsView` (upcoming calendar strip · recorded list · a `GlowOrbView` record orb docked at the bottom), `SessionRecordView`, `SessionScheduleForm`, `SessionDetailView` (playback, speaker-labeled transcript with a swap toggle, summary, Q&A).

## Design system (lavender)

Soft lavender palette in `Theme.swift` — `home*` tokens (`homeAccent`, `homeCard` white, `homeTint`, `homeHairline`, `homeBackgroundTop/Bottom`, etc.). Serif (New York) for headings/journal text. `homeCardBackground()` (in `Views/Home/HomeExtras.swift`) is the standard white card. Pull from these tokens rather than inventing colors.

### Key conventions

- **Autosave via the model, not a save button.** Editors bind to the `@Model`; SwiftData persists changes.
- **New `@Model`s must be registered** in `LilacApp`'s `ModelContainer`.
- **Immediate next step (the actual product wedge):** wire the journal to the session data — therapy-aware prompts ("last session you worked on X; did it come up?") and links between entries and sessions. That integration is the moat; the plain journal alone is a commodity.
