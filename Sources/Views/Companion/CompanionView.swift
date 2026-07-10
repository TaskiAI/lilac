import SwiftUI
import SwiftData

/// The AI companion: a gentle chat that listens and reflects your writing back.
/// The full transcript is persisted (`CompanionMessage`), so the conversation
/// picks up where it left off.
struct CompanionView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \CompanionMessage.createdAt, order: .forward) private var messages: [CompanionMessage]
    @Query(sort: \JournalEntry.createdAt, order: .reverse) private var entries: [JournalEntry]
    @Query(sort: \InsightReport.generatedAt, order: .reverse) private var reports: [InsightReport]
    @Query(sort: \TherapySession.date, order: .reverse) private var sessions: [TherapySession]

    @State private var draft = ""
    @State private var isThinking = false
    @State private var search = ""
    @FocusState private var inputFocused: Bool

    private var isSearching: Bool {
        !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var searchMatches: [CompanionMessage] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return messages.filter { $0.text.lowercased().contains(query) }
    }

    private let engine = CompanionEngine()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isSearching {
                    searchResults
                } else {
                    transcript
                    inputBar
                }
            }
            .background(
                LinearGradient(
                    colors: [.homeBackgroundTop, .homeBackgroundBottom],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("AI companion")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $search, prompt: "Search conversation")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(role: .destructive, action: clearConversation) {
                            Label("Clear conversation", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .disabled(messages.isEmpty)
                }
            }
        }
        .tint(.homeAccent)
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if messages.isEmpty {
                        WelcomeBubble()
                    }
                    ForEach(messages) { message in
                        MessageBubble(message: message)
                            .id(message.persistentModelID)
                    }
                    if isThinking {
                        TypingBubble().id("typing")
                    }
                }
                .padding(20)
            }
            .onChange(of: messages.count) { _, _ in scrollToBottom(proxy) }
            .onChange(of: isThinking) { _, _ in scrollToBottom(proxy) }
        }
    }

    @ViewBuilder
    private var searchResults: some View {
        if searchMatches.isEmpty {
            ContentUnavailableView.search(text: search)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(searchMatches) { message in
                        MessageBubble(message: message)
                            .id(message.persistentModelID)
                    }
                }
                .padding(20)
            }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Say what's on your mind…", text: $draft, axis: .vertical)
                .lineLimit(1...5)
                .focused($inputFocused)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    Capsule().fill(Color.homeCard)
                        .overlay(Capsule().stroke(Color.homeHairline, lineWidth: 1))
                )

            Button(action: send) {
                Image(systemName: "arrow.up")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(canSend ? Color.homeAccent : Color.homeSecondary.opacity(0.4)))
            }
            .disabled(!canSend)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isThinking
    }

    // MARK: Actions

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""
        inputFocused = false

        let userMessage = CompanionMessage(role: .user, text: text)
        context.insert(userMessage)

        let history = (messages + [userMessage]).map {
            CompanionTurn(role: $0.role, text: $0.text)
        }
        let grounding = recentJournalContext()

        isThinking = true
        Task { @MainActor in
            let reply = await engine.reply(to: history, context: grounding)
            context.insert(CompanionMessage(role: .assistant, text: reply))
            isThinking = false
        }
    }

    private func clearConversation() {
        for message in messages { context.delete(message) }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            if isThinking {
                proxy.scrollTo("typing", anchor: .bottom)
            } else if let last = messages.last {
                proxy.scrollTo(last.persistentModelID, anchor: .bottom)
            }
        }
    }

    /// A light, non-verbatim summary of recent journaling to ground replies:
    /// the latest AI insight (when present) plus the last few entries' prompt +
    /// typed text (no handwriting OCR, to stay instant).
    private func recentJournalContext() -> String? {
        var pieces: [String] = []
        if let report = reports.first, report.aiPowered, !report.summary.isEmpty {
            pieces.append("Recent insight: \(report.summary)")
        }
        let snippets: [String] = entries.prefix(3).compactMap { entry in
            var parts: [String] = []
            if !entry.prompt.isEmpty { parts.append(entry.prompt) }
            if let text = entry.text, !text.isEmpty { parts.append(text) }
            let joined = parts.joined(separator: " — ")
            return joined.isEmpty ? nil : String(joined.prefix(180))
        }
        if !snippets.isEmpty { pieces.append(snippets.joined(separator: " | ")) }

        // Recall from recorded therapy sessions: the most recent summaries, so the
        // companion can gently connect what the writer worked through there.
        let sessionNotes: [String] = sessions
            .prefix(2)
            .compactMap { session in
                guard let summary = session.summary, !summary.isEmpty else { return nil }
                let when = session.date.formatted(date: .abbreviated, time: .omitted)
                return "Session (\(when)): \(String(summary.prefix(220)))"
            }
        if !sessionNotes.isEmpty { pieces.append(sessionNotes.joined(separator: "\n")) }

        return pieces.isEmpty ? nil : pieces.joined(separator: "\n")
    }
}

// MARK: - Bubbles

private struct MessageBubble: View {
    let message: CompanionMessage

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 40) }
            Text(message.text)
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

private struct WelcomeBubble: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles").foregroundStyle(Color.homeAccent)
                Text("Your companion")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.homeAccentDeep)
            }
            Text("I'm here to listen and reflect your words back — no advice, no fixing. What's on your mind today?")
                .font(.system(.body, design: .serif))
                .foregroundStyle(Color.homeAccentDeep)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.homeCard)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.homeHairline, lineWidth: 1))
        )
    }
}

private struct TypingBubble: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Color.homeAccent.opacity(0.6))
                    .frame(width: 7, height: 7)
                    .scaleEffect(animating ? 1.2 : 0.7)
                    .animation(
                        .easeInOut(duration: 0.5).repeatForever().delay(Double(i) * 0.18),
                        value: animating
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.homeCard)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.homeHairline, lineWidth: 1))
        )
        .onAppear { animating = true }
    }
}
