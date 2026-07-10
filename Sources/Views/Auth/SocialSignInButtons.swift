import SwiftUI

/// The "Continue with Apple / Google" buttons shown on the account screen. Both
/// seed the local account via `AuthManager.signIn(with:...)`; there's no backend.
struct SocialSignInButtons: View {
    @EnvironmentObject private var auth: AuthManager

    @State private var appleCoordinator = AppleSignInCoordinator()
    @State private var errorMessage: String?
    @State private var busy = false

    var body: some View {
        VStack(spacing: 12) {
            SocialButton(
                title: "Continue with Apple",
                systemImage: "apple.logo",
                foreground: .white,
                background: .black,
                bordered: false,
                action: signInWithApple
            )
            SocialButton(
                title: "Continue with Google",
                systemImage: "g.circle.fill",
                foreground: Color.homeAccentDeep,
                background: Color.homeCard,
                bordered: true,
                action: signInWithGoogle
            )
        }
        .disabled(busy)
        .opacity(busy ? 0.6 : 1)
        .alert("Sign-in", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func signInWithApple() {
        busy = true
        Task {
            defer { busy = false }
            do {
                let credential = try await appleCoordinator.signIn()
                auth.signIn(with: .apple, id: credential.userID, name: credential.name, email: credential.email)
            } catch SocialAuthError.cancelled {
                // User backed out — say nothing.
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    private func signInWithGoogle() {
        busy = true
        Task {
            defer { busy = false }
            do {
                let credential = try await GoogleSignInCoordinator.signIn()
                auth.signIn(with: .google, id: credential.userID, name: credential.name, email: credential.email)
            } catch SocialAuthError.cancelled {
                // User backed out.
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }
}

private struct SocialButton: View {
    let title: String
    let systemImage: String
    let foreground: Color
    let background: Color
    let bordered: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.headline)
                Text(title)
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(background)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(bordered ? Color.homeHairline : .clear, lineWidth: 1)
                    )
            )
        }
    }
}
