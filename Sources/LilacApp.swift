import SwiftUI
import SwiftData

@main
struct LilacApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(
                for: JournalEntry.self,
                RewindCandidate.self,
                RewindSession.self,
                RewindSettings.self,
                AICallLog.self,
                CompanionMessage.self,
                Meeting.self
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
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
                        // The local stand-in for the scheduled backend job:
                        // classify pending entries and refresh candidates.
                        await RewindEngine(context: container.mainContext).run()
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
