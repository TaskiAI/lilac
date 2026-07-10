import SwiftUI
import SwiftData
import PencilKit

// Note: `JournalPage` hosts the transcript affordance because it is the writing
// surface (free diary + prompted). Sketch/photo/audio/log formats use their own
// screens and aren't handwriting, so they don't transcribe.

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

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage(WritingAssistant.enabledKey) private var assistEnabled = true
    @State private var lineSpacing: CGFloat
    @State private var headerHeight: CGFloat = 0
    @State private var scrollOffset: CGFloat = 0
    @State private var showTranscript = false

    // Writing assistant (idle / blank-page nudges)
    @State private var activityTick = 0
    @State private var assistSuggestions: [String] = []
    @State private var showAssist = false
    @State private var isFetchingAssist = false

    private var titleBinding: Binding<String> {
        Binding(
            get: { entry.title ?? "" },
            set: { entry.title = $0.isEmpty ? nil : $0 }
        )
    }

    init(
        entry: JournalEntry,
        theme: JournalTheme = .clean,
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

    private var hasInk: Bool {
        !loadedDrawing.bounds.isEmpty
    }

    // MARK: Writing assistant

    /// Any writing/editing activity: hide a shown panel and restart the idle
    /// timer (bumping `activityTick` re-triggers the `.task(id:)`).
    private func noteActivity() {
        if showAssist { withAnimation { showAssist = false } }
        activityTick += 1
    }

    private func dismissAssist() {
        withAnimation { showAssist = false }
    }

    /// Wait out the idle window, then offer nudges. Restarts on every activity
    /// (via `.task(id: activityTick)`); the blank page gets help sooner than a
    /// page you've paused on mid-writing.
    @MainActor
    private func runIdleTimer() async {
        guard assistEnabled, !showAssist else { return }
        let seconds: UInt64 = hasInk ? 20 : 8
        try? await Task.sleep(nanoseconds: seconds * 1_000_000_000)
        if Task.isCancelled { return }
        await offerAssist()
    }

    @MainActor
    private func offerAssist() async {
        guard assistEnabled, !isFetchingAssist else { return }
        isFetchingAssist = true
        defer { isFetchingAssist = false }

        // The words so far — prefer a fresh transcript, else recognize the ink now.
        let ink: String
        if entry.hasFreshTranscript, let transcript = entry.transcript {
            ink = transcript
        } else {
            ink = await HandwritingTextExtractor.text(from: entry.drawingData)
        }
        if Task.isCancelled { return }

        var parts: [String] = []
        if let text = entry.text, !text.isEmpty { parts.append(text) }
        if !ink.isEmpty { parts.append(ink) }
        let current = parts.joined(separator: "\n")

        let suggestions = await WritingAssistant.suggestions(prompt: entry.prompt, currentText: current)
        if Task.isCancelled || suggestions.isEmpty { return }
        assistSuggestions = suggestions
        withAnimation { showAssist = true }
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
                    onChange: { drawing in
                        entry.drawingData = drawing.dataRepresentation()
                        noteActivity()
                    },
                    onScroll: { scrollOffset = $0 }
                )

                header
                    .background(theme.paper)
                    .offset(y: headerTranslation)
            }

            if showAssist {
                WritingAssistPanel(
                    theme: theme,
                    suggestions: assistSuggestions,
                    onPick: { _ in dismissAssist() },
                    onDismiss: dismissAssist
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            spacingControl
        }
        .background(theme.paper)
        .task(id: activityTick) { await runIdleTimer() }
        .onChange(of: entry.title) { _, _ in noteActivity() }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(theme.paper, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .tint(theme.ink)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showTranscript = true
                } label: {
                    Image(systemName: "text.magnifyingglass")
                }
                .accessibilityLabel("Transcript")

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                }
                .accessibilityLabel("Done writing")
            }
        }
        .sheet(isPresented: $showTranscript) {
            TranscriptView(entry: entry)
        }
        .onDisappear {
            // Transcribe fresh writing as soon as the page closes, so the words
            // are ready for search and the AI tools without waiting for launch.
            guard entry.needsTranscription else { return }
            let context = context
            Task { @MainActor [entry] in
                await TranscriptionEngine(context: context).transcribe(entry)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                TextField("Untitled", text: titleBinding, axis: .vertical)
                    .font(.system(.largeTitle, design: .serif))
                    .foregroundStyle(theme.ink)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.done)
                Text(entry.createdAt.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
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
