import SwiftUI

/// First-run account creation. Since Lilac is local-only, this collects a name
/// (and optional email) and sets up the app lock: a passcode and, if available,
/// Face ID / Touch ID.
struct AccountCreationView: View {
    @EnvironmentObject private var auth: AuthManager

    private enum Step { case profile, choosePasscode, confirmPasscode }
    @State private var step: Step = .profile

    @State private var name = ""
    @State private var email = ""
    @State private var useBiometrics = true

    @State private var firstCode = ""
    @State private var confirmCode = ""
    @State private var shake: CGFloat = 0
    @State private var mismatch = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.white, .homeBackgroundBottom],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer(minLength: 0)
                LilacLockup(orbSize: 92, wordmarkSize: 34)

                switch step {
                case .profile: profileStep
                case .choosePasscode: passcodeStep(
                    title: "Create a passcode",
                    subtitle: "You'll use this to unlock your journal.",
                    code: $firstCode
                )
                case .confirmPasscode: passcodeStep(
                    title: "Confirm your passcode",
                    subtitle: mismatch ? "That didn't match. Try again." : "Enter it once more.",
                    code: $confirmCode
                )
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 32)
        }
        .animation(.easeInOut(duration: 0.25), value: step)
    }

    // MARK: Steps

    private var profileStep: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text("Create your space")
                    .font(.system(.title2, design: .serif).weight(.semibold))
                    .foregroundStyle(Color.homeAccentDeep)
                Text("A private place for your thoughts.")
                    .font(.subheadline)
                    .foregroundStyle(Color.homeSecondary)
            }

            VStack(spacing: 12) {
                AuthField(title: "Your name", text: $name)
                    .textContentType(.givenName)
                AuthField(title: "Email (optional)", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
            }

            if auth.biometryAvailable {
                Toggle(isOn: $useBiometrics) {
                    Label("Unlock with \(auth.biometryName)", systemImage: biometrySymbol)
                        .font(.subheadline)
                        .foregroundStyle(Color.homeAccentDeep)
                }
                .tint(.homeAccent)
                .padding(.horizontal, 4)
            }

            Button {
                step = .choosePasscode
            } label: {
                Text("Continue")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Capsule().fill(canContinue ? Color.homeAccent : Color.homeSecondary.opacity(0.4)))
            }
            .disabled(!canContinue)

            Button("Skip for now — no passcode") { createWithoutPasscode() }
                .font(.footnote)
                .foregroundStyle(Color.homeSecondary)
        }
    }

    private func passcodeStep(title: String, subtitle: String, code: Binding<String>) -> some View {
        VStack(spacing: 24) {
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(.title3, design: .serif).weight(.medium))
                    .foregroundStyle(Color.homeAccentDeep)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(mismatch ? .red.opacity(0.8) : Color.homeSecondary)
            }
            PasscodePad(code: code, length: 4) { entered in
                handlePasscodeEntry(entered)
            }
            .modifier(ShakeModifier(shake: shake))

            Button("Back") { goBack() }
                .font(.footnote)
                .foregroundStyle(Color.homeSecondary)
        }
    }

    // MARK: Logic

    private var canContinue: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var biometrySymbol: String {
        auth.biometryType == .touchID ? "touchid" : "faceid"
    }

    private func handlePasscodeEntry(_ entered: String) {
        switch step {
        case .choosePasscode:
            mismatch = false
            confirmCode = ""
            step = .confirmPasscode
        case .confirmPasscode:
            if entered == firstCode {
                auth.createAccount(
                    name: name,
                    email: email,
                    passcode: firstCode,
                    useBiometrics: useBiometrics
                )
            } else {
                mismatch = true
                withAnimation(.linear(duration: 0.4)) { shake += 1 }
                confirmCode = ""
                firstCode = ""
                step = .choosePasscode
            }
        case .profile:
            break
        }
    }

    private func goBack() {
        switch step {
        case .confirmPasscode:
            confirmCode = ""
            firstCode = ""
            mismatch = false
            step = .choosePasscode
        case .choosePasscode:
            firstCode = ""
            step = .profile
        case .profile:
            break
        }
    }

    private func createWithoutPasscode() {
        auth.createAccount(name: name, email: email, passcode: nil, useBiometrics: false)
    }
}

/// A rounded text field styled for the auth screens.
private struct AuthField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        TextField(title, text: $text)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.homeCard)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.homeHairline, lineWidth: 1))
            )
    }
}

/// Applies the horizontal shake keyed on a changing value.
struct ShakeModifier: ViewModifier {
    var shake: CGFloat
    func body(content: Content) -> some View {
        content.modifier(ShakeEffect(animatableData: shake))
    }
}
