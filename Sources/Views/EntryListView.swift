import SwiftUI

/// The app shell once unlocked: two tabs — the typed Journal and the
/// therapist-session assistant. Deliberately lean (v2 therapy companion).
struct RootTabView: View {
    @EnvironmentObject private var auth: AuthManager
    @State private var selection: Tab = .journal

    enum Tab { case journal, sessions }

    var body: some View {
        TabView(selection: $selection) {
            JournalListView()
                .tabItem { Label("Journal", systemImage: "book") }
                .tag(Tab.journal)

            SessionsView()
                .tabItem { Label("Sessions", systemImage: "waveform") }
                .tag(Tab.sessions)
        }
        .tint(.homeAccent)
    }
}
