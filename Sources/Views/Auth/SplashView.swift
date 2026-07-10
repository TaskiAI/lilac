import SwiftUI

/// The launch / welcome screen: the Lilac lockup on a soft white field, shown
/// briefly on cold start while the app decides where to send you.
struct SplashView: View {
    @State private var appeared = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.white, .homeBackgroundBottom],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            LilacLockup(orbSize: 120, wordmarkSize: 44)
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.94)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.7)) { appeared = true }
        }
    }
}
