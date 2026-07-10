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
            EntryListView()
                .tint(.lilac)
                .task {
                    // The local stand-in for the scheduled backend job: classify
                    // pending entries and refresh candidates. No-ops when the
                    // feature is off or DeepSeek isn't configured.
                    await RewindEngine(context: container.mainContext).run()
                }
        }
        .modelContainer(container)
    }
}
