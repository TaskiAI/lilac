import SwiftUI
import SwiftData

/// A recorded session: play the audio, read the speaker-labeled transcript, see
/// the AI summary, and ask questions grounded in the transcript. Transcription /
/// summary run automatically when the session is still `.transcribing`.
struct SessionDetailView: View {
    @Bindable var session: TherapySession

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var player = AudioPlayer()
    @State private var draft = ""
    @State private var isThinking = false
    @State private var isSummarizing = false
    @FocusState private var inputFocused: Bool

    private let ai = SessionAI()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                audioPlayer
                summarySection
                transcriptSection
                qaSection
            }
            .padding(20)
            .padding(.bottom, 12)
        }
        .background(
            LinearGradient(
                colors: [.homeBackgroundTop, .homeBackgroundBottom],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationTitle(session.title.isEmpty ? "Session" : session.title)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { askBar }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    if !session.segments.isEmpty {
                        Button {
                            session.swapSpeakers.toggle()
                        } label: {
                            Label("Swap speaker labels", systemImage: "arrow.left.arrow.right")
                        }
                    }
                    Button {
                        Task { await reprocess() }
                    } label: {
                        Label("Re-transcribe", systemImage: "arrow.clockwise")
                    }
                    Button(role: .destructive, action: deleteSession) {
                        Label("Delete session", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .task { await SessionProcessor(context: context).processIfNeeded(session) }
        .onDisappear { player.stop() }
        .tint(.homeAccent)
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(session.date.formatted(date: .complete, time: .shortened))
                .font(.system(.subheadline, design: .serif))
                .foregroundStyle(Color.homeSecondary)
            if !session.therapistName.isEmpty {
                Label(session.therapistName, systemImage: "person")
                    .font(.caption)
                    .foregroundStyle(Color.homeAccent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Audio

    @ViewBuilder
    private var audioPlayer: some View {
        if let filename = session.audioFilename, SessionAudioStore.exists(filename) {
            let id = audioID(filename)
            let isPlaying = player.playingID == id
            Button {
                player.toggle(url: SessionAudioStore.url(for: filename), id: id)
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(Color.homeAccent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isPlaying ? "Playing…" : "Play recording")
                            .font(.system(.subheadline, design: .serif).weight(.medium))
                            .foregroundStyle(Color.homeHeading)
                        Text(SessionRecordView.durationText(session.duration))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Color.homeSecondary)
                    }
                    Spacer()
                    Image(systemName: "waveform")
                        .foregroundStyle(Color.homeAccent.opacity(0.5))
                }
                .padding(14)
                .frame(maxWidth: .infinity)
                .homeCardBackground()
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Summary

    @ViewBuilder
    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Summary", systemImage: "sparkles")
                    .font(.system(.headline, design: .serif))
                    .foregroundStyle(Color.homeHeading)
                Spacer()
                if session.state == .ready {
                    Button {
                        Task { await regenerateSummary() }
                    } label: {
                        if isSummarizing {
                            ProgressView().controlSize(.mini)
                        } else {
                            Image(systemName: "arrow.clockwise").font(.caption)
                        }
                    }
                    .disabled(isSummarizing)
                }
            }

            switch session.state {
            case .transcribing:
                processingRow("Transcribing and summarizing this session…")
            case .failed:
                failedRow
            case .scheduled, .ready:
                if let summary = session.summary, !summary.isEmpty {
                    Text(summary)
                        .font(.system(.subheadline, design: .serif))
                        .foregroundStyle(Color.homeAccentDeep)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("No summary yet.")
                        .font(.caption)
                        .foregroundStyle(Color.homeSecondary)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .homeCardBackground()
    }

    private func processingRow(_ text: String) -> some View {
        HStack(spacing: 10) {
            ProgressView().controlSize(.small)
            Text(text)
                .font(.caption)
                .foregroundStyle(Color.homeSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var failedRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Couldn't transcribe this recording", systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.orange)
            Button {
                Task { await reprocess() }
            } label: {
                Label("Try again", systemImage: "arrow.clockwise")
                    .font(.caption.weight(.medium))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Transcript

    @ViewBuilder
    private var transcriptSection: some View {
        if !session.segments.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Transcript")
                    .font(.system(.headline, design: .serif))
                    .foregroundStyle(Color.homeHeading)
                ForEach(session.segments) { segment in
                    SegmentBubble(
                        label: label(for: segment.speaker),
                        text: segment.text,
                        isYou: isYou(segment.speaker)
                    )
                }
            }
        } else if let transcript = session.transcript, !transcript.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Text("Transcript")
                        .font(.system(.headline, design: .serif))
                        .foregroundStyle(Color.homeHeading)
                    Text("· no speaker labels")
                        .font(.caption)
                        .foregroundStyle(Color.homeSecondary)
                }
                Text(transcript)
                    .font(.system(.subheadline, design: .serif))
                    .foregroundStyle(Color.homeAccentDeep)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .homeCardBackground()
            }
        }
    }

    // MARK: Q&A

    @ViewBuilder
    private var qaSection: some View {
        if !session.chat.isEmpty || isThinking {
            VStack(alignment: .leading, spacing: 12) {
                Label("Questions", systemImage: "text.bubble")
                    .font(.system(.headline, design: .serif))
                    .foregroundStyle(Color.homeHeading)
                ForEach(session.chat) { message in
                    ChatBubble(text: message.text, isUser: message.isUser)
                }
                if isThinking {
                    ChatBubble(text: "…", isUser: false)
                }
            }
        }
    }

    private var askBar: some View {
        HStack(spacing: 10) {
            TextField("Ask about this session…", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .focused($inputFocused)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    Capsule().fill(Color.homeCard)
                        .overlay(Capsule().stroke(Color.homeHairline, lineWidth: 1))
                )

            Button(action: ask) {
                Image(systemName: "arrow.up")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(canAsk ? Color.homeAccent : Color.homeSecondary.opacity(0.4)))
            }
            .disabled(!canAsk)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private var canAsk: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isThinking
            && (session.transcript?.isEmpty == false)
    }

    // MARK: Actions

    private func ask() {
        let question = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }
        draft = ""
        inputFocused = false

        let history = session.chat
        session.chat = history + [SessionChatMessage(isUser: true, text: question)]
        isThinking = true

        Task { @MainActor in
            let reply = await ai.answer(
                question: question,
                transcript: session.transcript ?? "",
                history: history
            )
            session.chat = session.chat + [SessionChatMessage(isUser: false, text: reply)]
            isThinking = false
        }
    }

    private func regenerateSummary() async {
        isSummarizing = true
        if let summary = await ai.summarize(transcript: session.transcript ?? "") {
            session.summary = summary
        }
        isSummarizing = false
    }

    private func reprocess() async {
        await SessionProcessor(context: context).reprocess(session)
    }

    private func deleteSession() {
        if let filename = session.audioFilename { SessionAudioStore.delete(filename) }
        context.delete(session)
        dismiss()
    }

    // MARK: Speaker mapping

    /// Distinct speakers in the order they first appear.
    private var orderedSpeakers: [String] {
        var seen: [String] = []
        for segment in session.segments where !seen.contains(segment.speaker) {
            seen.append(segment.speaker)
        }
        return seen
    }

    /// Map a raw diarization label to a friendly one. First speaker → therapist,
    /// second → "You" (swappable, since diarization can't know who's who).
    private func label(for speaker: String) -> String {
        let order = orderedSpeakers
        guard let index = order.firstIndex(of: speaker) else { return "Speaker \(speaker)" }
        let therapistIndex = session.swapSpeakers ? 1 : 0
        if index == therapistIndex {
            return session.therapistName.isEmpty ? "Therapist" : session.therapistName
        }
        if index == (therapistIndex == 0 ? 1 : 0) {
            return "You"
        }
        return "Speaker \(speaker)"
    }

    private func isYou(_ speaker: String) -> Bool {
        let order = orderedSpeakers
        guard let index = order.firstIndex(of: speaker) else { return false }
        let youIndex = session.swapSpeakers ? 0 : 1
        return index == youIndex
    }

    /// A stable id for the recording, derived from its filename (`<uuid>.m4a`).
    private func audioID(_ filename: String) -> UUID {
        UUID(uuidString: String(filename.dropLast(4))) ?? UUID()
    }
}

// MARK: - Bubbles

/// A speaker-labeled transcript utterance; "You" leans right, others left.
private struct SegmentBubble: View {
    let label: String
    let text: String
    let isYou: Bool

    var body: some View {
        VStack(alignment: isYou ? .trailing : .leading, spacing: 3) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.homeAccent)
            Text(text)
                .font(.system(.subheadline, design: .serif))
                .foregroundStyle(isYou ? .white : Color.homeAccentDeep)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isYou ? Color.homeAccent : Color.homeCard)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(isYou ? .clear : Color.homeHairline, lineWidth: 1)
                        )
                )
        }
        .frame(maxWidth: .infinity, alignment: isYou ? .trailing : .leading)
    }
}

private struct ChatBubble: View {
    let text: String
    let isUser: Bool

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 40) }
            Text(text)
                .font(isUser ? .body : .system(.body, design: .serif))
                .foregroundStyle(isUser ? .white : Color.homeAccentDeep)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(isUser ? Color.homeAccent : Color.homeCard)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(isUser ? .clear : Color.homeHairline, lineWidth: 1)
                        )
                )
            if !isUser { Spacer(minLength: 40) }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }
}
