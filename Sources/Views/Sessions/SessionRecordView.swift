import SwiftUI
import SwiftData

/// Record a therapy session: a big mic button with a live timer, plus optional
/// title / therapist fields. On save the audio is written to `SessionAudioStore`,
/// a `TherapySession` is created in the `.transcribing` state, and processing
/// (diarize → summarize) kicks off in the background.
struct SessionRecordView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// An existing scheduled session being recorded into, if any.
    var scheduled: TherapySession? = nil

    @State private var recorder = AudioRecorder()
    @State private var title = ""
    @State private var therapist = ""
    @State private var recording: (data: Data, duration: TimeInterval)?
    @State private var permissionDenied = false

    private var hasRecording: Bool { recording != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 26) {
                    fields
                    recordControl
                    if DiarizationClient.shared.isConfigured {
                        privacyNote(
                            "This session's audio is sent securely to the transcription service to label who's speaking."
                        )
                    } else {
                        privacyNote(
                            "Transcribed on-device without speaker labels. Add a diarization key to tell speakers apart."
                        )
                    }
                }
                .padding(24)
            }
            .background(
                LinearGradient(
                    colors: [.homeBackgroundTop, .homeBackgroundBottom],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("New session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { cancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!hasRecording || recorder.status == .recording)
                }
            }
            .onAppear(perform: loadScheduled)
            .alert("Microphone access needed", isPresented: $permissionDenied) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Enable microphone access in Settings to record a session.")
            }
        }
        .tint(.homeAccent)
    }

    // MARK: Sections

    private var fields: some View {
        VStack(spacing: 12) {
            LabeledField(title: "Title", text: $title, placeholder: "e.g. Weekly therapy")
            LabeledField(title: "With", text: $therapist, placeholder: "Therapist's name")
        }
    }

    private var recordControl: some View {
        VStack(spacing: 14) {
            Button(action: toggleRecording) {
                ZStack {
                    Circle()
                        .fill(Color.homeAccent.opacity(0.12))
                        .frame(width: 120, height: 120)
                    Circle()
                        .fill(recorder.status == .recording ? Color.red.opacity(0.9) : Color.homeAccent)
                        .frame(width: 88, height: 88)
                    Image(systemName: recorder.status == .recording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(.white)
                }
            }
            .disabled(hasRecording && recorder.status != .recording)

            if recorder.status == .recording {
                Text(Self.durationText(recorder.elapsed))
                    .font(.system(.title3, design: .serif).monospacedDigit())
                    .foregroundStyle(Color.homeAccentDeep)
                Text("Recording…")
                    .font(.caption)
                    .foregroundStyle(Color.homeSecondary)
            } else if let recording {
                Label("Recorded \(Self.durationText(recording.duration))", systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color.homeAccent)
                Text("Save to transcribe and summarize this session.")
                    .font(.caption)
                    .foregroundStyle(Color.homeSecondary)
            } else {
                Text("Tap to start recording")
                    .font(.caption)
                    .foregroundStyle(Color.homeSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private func privacyNote(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lock.shield")
                .font(.caption)
                .foregroundStyle(Color.homeAccent)
            Text(text)
                .font(.caption)
                .foregroundStyle(Color.homeSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.homeTint))
    }

    // MARK: Actions

    private func loadScheduled() {
        guard let scheduled else { return }
        title = scheduled.title
        therapist = scheduled.therapistName
    }

    private func toggleRecording() {
        if recorder.status == .recording {
            recorder.stop { url, duration in
                Task { @MainActor in
                    if let data = try? Data(contentsOf: url) {
                        recording = (data, duration)
                    }
                    try? FileManager.default.removeItem(at: url)
                }
            }
        } else {
            Task { @MainActor in
                guard await recorder.requestPermission() else {
                    permissionDenied = true
                    return
                }
                recording = nil
                try? recorder.start()
            }
        }
    }

    private func save() {
        guard let recording, let filename = SessionAudioStore.save(data: recording.data) else { return }

        let session = scheduled ?? TherapySession()
        session.title = title.trimmingCharacters(in: .whitespaces)
        session.therapistName = therapist.trimmingCharacters(in: .whitespaces)
        session.audioFilename = filename
        session.duration = recording.duration
        session.date = .now
        session.state = .transcribing
        if scheduled == nil { context.insert(session) }

        // Kick off transcription + summary. A free-standing Task keeps running
        // after this sheet dismisses; the processor writes results back into the
        // shared context.
        let processor = SessionProcessor(context: context)
        Task { @MainActor in await processor.process(session) }

        dismiss()
    }

    private func cancel() {
        if recorder.status == .recording {
            recorder.stop { url, _ in try? FileManager.default.removeItem(at: url) }
        }
        dismiss()
    }

    static func durationText(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

/// A titled text field styled for the lavender home surface.
private struct LabeledField: View {
    let title: String
    @Binding var text: String
    let placeholder: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.homeSecondary)
            TextField(placeholder, text: $text)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.homeCard)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.homeHairline, lineWidth: 1))
                )
        }
    }
}
