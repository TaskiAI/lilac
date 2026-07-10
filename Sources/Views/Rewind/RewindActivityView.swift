import SwiftUI
import SwiftData

/// The home-screen "Activities" entry point for Rewind. Shows a resurfaced entry
/// when one is eligible (all guardrails applied in `RewindEngine`/`RewindSelector`),
/// plus always-available ways to browse themes and adjust settings.
struct RewindActivitySection: View {
    @Environment(\.modelContext) private var context

    @State private var presentation: RewindEngine.Presentation?
    @State private var bridge: String?
    @State private var reflectSource: JournalEntry?
    @State private var showBrowser = false
    @State private var showSettings = false
    @State private var loaded = false

    private var engine: RewindEngine { RewindEngine(context: context) }

    var body: some View {
        VStack(spacing: 12) {
            if let presentation {
                RewindCard(
                    entry: presentation.entry,
                    mode: presentation.mode,
                    bridge: bridge,
                    onReflect: { reflect(presentation) },
                    onDismiss: { respond(presentation, .dismissed) },
                    onMute: { respond(presentation, .muted) }
                )
            }
            exploreRow
        }
        .task { load() }
        .sheet(item: $reflectSource) { source in
            ThenNowView(source: source, engine: engine)
        }
        .sheet(isPresented: $showBrowser) {
            ThreadRevisitBrowser(engine: engine)
        }
        .sheet(isPresented: $showSettings) {
            RewindSettingsPanel(engine: engine)
        }
    }

    private var exploreRow: some View {
        HStack(spacing: 12) {
            Button { showBrowser = true } label: {
                Label("Revisit a theme", systemImage: "square.stack.3d.up")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .background(Color.lilacSoft, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            Button { showSettings = true } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.subheadline)
                    .padding(12)
                    .background(Color.lilacSoft, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Rewind settings")
        }
        .foregroundStyle(Color.lilac)
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        guard let next = engine.next() else { return }
        engine.markShown(next)
        presentation = next
        Task { bridge = await engine.bridge(for: next.entry) }
    }

    private func respond(_ presentation: RewindEngine.Presentation, _ outcome: RewindOutcome) {
        engine.record(presentation, outcome: outcome)
        withAnimation {
            self.presentation = nil
            bridge = nil
        }
    }

    private func reflect(_ presentation: RewindEngine.Presentation) {
        engine.record(presentation, outcome: .reflected)
        reflectSource = presentation.entry
        withAnimation {
            self.presentation = nil
            bridge = nil
        }
    }
}
