import SwiftUI
import SwiftData

@main
struct LilacApp: App {
    var body: some Scene {
        WindowGroup {
            EntryListView()
                .tint(.lilac)
        }
        .modelContainer(for: JournalEntry.self)
    }
}
