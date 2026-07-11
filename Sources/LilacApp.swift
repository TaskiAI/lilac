import SwiftUI
import SwiftData

@main
struct LilacApp: App {
    let container: ModelContainer

    init() {
        let schema = Schema([
            JournalEntry.self,
            RewindCandidate.self,
            RewindSession.self,
            RewindSettings.self,
            AICallLog.self,
            CompanionMessage.self,
            Meeting.self,
            InsightReport.self,
            TherapySession.self,
        ])

        // Back the store with private CloudKit mirroring, so a user's journal
        // syncs to their iCloud and survives a lost/replaced device. Requires the
        // iCloud + CloudKit entitlement and a provisioned container (see
        // project.yml). If CloudKit isn't available — not signed into iCloud, the
        // entitlement missing in a dev build, an unprovisioned container — fall
        // back to a local-only store so the app still launches (just without
        // backup). Session audio lives on disk, so only transcripts/summaries and
        // the handwritten entries themselves are mirrored, not the raw audio.
        do {
            let cloud = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
            container = try ModelContainer(for: schema, configurations: cloud)
        } catch {
            do {
                let local = ModelConfiguration(schema: schema)
                container = try ModelContainer(for: schema, configurations: local)
            } catch {
                fatalError("Failed to create ModelContainer: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
        }
        .modelContainer(container)
    }
}

/// Gates the app behind the splash + account/lock flow, then shows the journal.
/// Re-engages the lock whenever the app is backgrounded.
private struct RootView: View {
    let container: ModelContainer

    @StateObject private var auth = AuthManager()
    @Environment(\.scenePhase) private var scenePhase
    @State private var didBootstrap = false

    var body: some View {
        Group {
            switch auth.phase {
            case .launching:
                SplashView()
            case .needsAccount:
                AccountCreationView()
                    .environmentObject(auth)
            case .locked:
                LockView()
                    .environmentObject(auth)
            case .unlocked:
                EntryListView()
                    .tint(.lilac)
                    .environmentObject(auth)
                    .task {
                        // Keep handwriting transcripts current first, so the tools
                        // below read real words. Then the local stand-in for the
                        // scheduled backend job: classify entries and refresh
                        // candidates, then refresh insights if they've gone stale
                        // (both gated on their own privacy settings).
                        await TranscriptionEngine(context: container.mainContext).run()
                        await RewindEngine(context: container.mainContext).run()
                        // Resume any session transcription interrupted by a close.
                        await SessionProcessor(context: container.mainContext).runPending()
                        let insights = InsightEngine(context: container.mainContext)
                        if insights.isEnabled, insights.isStale() {
                            let focuses = FocusAreas.decode(
                                UserDefaults.standard.string(forKey: FocusAreas.storageKey) ?? ""
                            )
                            await insights.generate(focuses: focuses)
                        }
                    }
            }
        }
        .task {
            // Hold the splash briefly on cold launch, then decide where to go.
            guard !didBootstrap else { return }
            didBootstrap = true
            try? await Task.sleep(for: .seconds(1.3))
            auth.bootstrap()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { auth.lockIfNeeded() }
        }
    }
}
