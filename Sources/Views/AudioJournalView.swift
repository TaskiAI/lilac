import SwiftUI
import SwiftData

/// The Audio journal editor: record a voice note, optionally transcribe it into
/// the text body, keep the audio to play back, and keep writing as much as you
/// like. Recordings persist as `entry.audioClips`; the transcription and any
/// typed additions persist as `entry.text`.
struct AudioJournalView: View {
    @Bindable var entry: JournalEntry
    var theme: JournalTheme = .diary

    @State private var recorder = AudioRecorder()
    @State private var player = AudioPlayer()

    @State private var clips: [AudioClip] = []
    @State private var transcribe = true
    @State private var isTranscribing = false
    @State private var permissionDenied = false

    private var textBinding: Binding<String> {
        Binding(get: { entry.text ?? "" }, set: { entry.text = $0 })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                clipList
                recordControl
                writingArea
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .background(theme.paper)
        .navigationTitle("Audio")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(theme.paper, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .tint(theme.ink)
        .task { if clips.isEmpty { clips = entry.audioClips } }
        .alert("Microphone access needed", isPresented: $permissionDenied) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Enable microphone access in Settings to record a voice note.")
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.createdAt.formatted(.dateTime.weekday(.wide)))
                .font(.system(.largeTitle, design: .serif))
                .foregroundStyle(theme.ink)
            Text(entry.createdAt.formatted(.dateTime.day().month(.wide).year()))
                .font(.system(.subheadline, design: .serif).italic())
                .foregroundStyle(theme.ink.opacity(0.55))
        }
    }

    @ViewBuilder
    private var clipList: some View {
        if !clips.isEmpty {
            VStack(spacing: 8) {
                ForEach(clips) { clip in
                    ClipRow(
                        clip: clip,
                        isPlaying: player.playingID == clip.id,
                        theme: theme,
                        onToggle: { player.toggle(clip) },
                        onDelete: { delete(clip) }
                    )
                }
            }
        }
    }

    private var recordControl: some View {
        VStack(spacing: 10) {
            Button(action: toggleRecording) {
                ZStack {
                    Circle()
                        .fill(theme.margin.opacity(0.15))
                        .frame(width: 76, height: 76)
                    Image(systemName: recorder.status == .recording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(theme.margin)
                }
            }
            .disabled(isTranscribing)

            if recorder.status == .recording {
                Text(Self.durationText(recorder.elapsed))
                    .font(.system(.callout, design: .serif).monospacedDigit())
                    .foregroundStyle(theme.ink.opacity(0.7))
            } else if isTranscribing {
                Label("Transcribing…", systemImage: "waveform")
                    .font(.system(.caption, design: .serif))
                    .foregroundStyle(theme.ink.opacity(0.6))
            } else {
                Toggle(isOn: $transcribe) {
                    Text("Transcribe to text")
                        .font(.system(.subheadline, design: .serif))
                        .foregroundStyle(theme.ink.opacity(0.7))
                }
                .tint(theme.margin)
                .frame(maxWidth: 260)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .overlay(alignment: .top) {
            Rectangle().fill(theme.rule).frame(height: 0.75)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.rule).frame(height: 0.75)
        }
    }

    private var writingArea: some View {
        ZStack(alignment: .topLeading) {
            if (entry.text ?? "").isEmpty {
                Text("Write more…")
                    .font(.system(.body, design: .serif))
                    .foregroundStyle(theme.ink.opacity(0.3))
                    .padding(.top, 8)
                    .padding(.leading, 5)
            }
            TextEditor(text: textBinding)
                .font(.system(.body, design: .serif))
                .foregroundStyle(theme.ink)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 220)
        }
    }

    // MARK: - Actions

    private func toggleRecording() {
        if recorder.status == .recording {
            recorder.stop { url, duration in
                Task { @MainActor in await finishRecording(url: url, duration: duration) }
            }
        } else {
            Task { @MainActor in
                guard await recorder.requestPermission() else {
                    permissionDenied = true
                    return
                }
                try? recorder.start()
            }
        }
    }

    private func finishRecording(url: URL, duration: TimeInterval) async {
        guard let data = try? Data(contentsOf: url) else { return }
        clips.append(AudioClip(data: data, duration: duration))
        entry.audioClips = clips

        if transcribe {
            isTranscribing = true
            if await SpeechTranscriber.requestPermission(),
               let text = try? await SpeechTranscriber.transcribe(url: url),
               !text.isEmpty {
                appendText(text)
            }
            isTranscribing = false
        }

        try? FileManager.default.removeItem(at: url)
    }

    private func appendText(_ addition: String) {
        let existing = entry.text ?? ""
        entry.text = existing.isEmpty ? addition : existing + "\n\n" + addition
    }

    private func delete(_ clip: AudioClip) {
        if player.playingID == clip.id { player.stop() }
        clips.removeAll { $0.id == clip.id }
        entry.audioClips = clips
    }

    static func durationText(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

/// A saved voice note: play/stop, its length, and a delete affordance.
private struct ClipRow: View {
    let clip: AudioClip
    let isPlaying: Bool
    let theme: JournalTheme
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(theme.margin)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Voice note")
                    .font(.system(.subheadline, design: .serif))
                    .foregroundStyle(theme.ink)
                Text(AudioJournalView.durationText(clip.duration))
                    .font(.system(.caption, design: .serif).monospacedDigit())
                    .foregroundStyle(theme.ink.opacity(0.55))
            }
            Spacer(minLength: 0)
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.subheadline)
                    .foregroundStyle(theme.ink.opacity(0.4))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(theme.margin.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}
