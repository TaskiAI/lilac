import SwiftUI

/// The lock screen — Lilac's "login". Gates the app on launch and when
/// returning from the background. Unlock with the passcode or Face ID / Touch ID.
struct LockView: View {
    @EnvironmentObject private var auth: AuthManager

    @State private var code = ""
    @State private var shake: CGFloat = 0
    @State private var wrong = false
    @State private var showResetConfirm = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.white, .homeBackgroundBottom],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer(minLength: 0)

                VStack(spacing: 10) {
                    LilacLockup(orbSize: 96, wordmarkSize: 34)
                    Text(greeting)
                        .font(.system(.title3, design: .serif))
                        .foregroundStyle(Color.homeAccentDeep)
                    Text(wrong ? "Wrong passcode. Try again." : "Enter your passcode to continue.")
                        .font(.subheadline)
                        .foregroundStyle(wrong ? .red.opacity(0.8) : Color.homeSecondary)
                }

                PasscodePad(
                    code: $code,
                    length: 4,
                    showsBiometryButton: auth.biometricsEnabled,
                    biometrySymbol: biometrySymbol,
                    onBiometry: { Task { await tryBiometrics() } },
                    onComplete: submit
                )
                .modifier(ShakeModifier(shake: shake))

                Button("Forgot passcode?") { showResetConfirm = true }
                    .font(.footnote)
                    .foregroundStyle(Color.homeSecondary)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 32)
        }
        .task {
            // Offer Face ID immediately on appear.
            if auth.biometricsEnabled { await tryBiometrics() }
        }
        .confirmationDialog(
            "Reset your passcode?",
            isPresented: $showResetConfirm,
            titleVisibility: .visible
        ) {
            Button("Reset account", role: .destructive) { auth.resetAccount() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your passcode can't be recovered. Resetting starts a new account setup — your journal entries are kept.")
        }
    }

    private var greeting: String {
        let name = auth.displayName
        return name.isEmpty ? "Welcome back" : "Welcome back, \(name)"
    }

    private var biometrySymbol: String {
        auth.biometryType == .touchID ? "touchid" : "faceid"
    }

    private func submit(_ entered: String) {
        if auth.verifyPasscode(entered) {
            auth.unlock()
        } else {
            wrong = true
            withAnimation(.linear(duration: 0.4)) { shake += 1 }
            code = ""
        }
    }

    private func tryBiometrics() async {
        if await auth.authenticateWithBiometrics() {
            auth.unlock()
        }
    }
}
