import SwiftUI

/// The settings hub: profile, app-lock management (passcode + biometrics), and
/// account actions. Reads and mutates `AuthManager`.
struct SettingsView: View {
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var sheet: SettingsSheet?
    @State private var showResetConfirm = false
    @AppStorage(InsightEngine.enabledKey) private var insightsEnabled = true
    @AppStorage(WritingAssistant.enabledKey) private var assistEnabled = true

    var body: some View {
        NavigationStack {
            List {
                profileSection
                securitySection
                privacySection
                aboutSection
                accountSection
            }
            .scrollContentBackground(.hidden)
            .background(
                LinearGradient(colors: [.homeBackgroundTop, .homeBackgroundBottom],
                               startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            )
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $sheet) { which in
                switch which {
                case .editProfile:
                    ProfileEditView().environmentObject(auth)
                case .passcode(let mode):
                    PasscodeFlowSheet(mode: mode).environmentObject(auth)
                }
            }
            .confirmationDialog(
                "Reset account?",
                isPresented: $showResetConfirm,
                titleVisibility: .visible
            ) {
                Button("Reset account", role: .destructive) { auth.resetAccount() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This clears your profile and passcode and starts setup over. Your journal entries are kept.")
            }
        }
        .tint(.homeAccent)
    }

    // MARK: Sections

    private var profileSection: some View {
        Section {
            Button { sheet = .editProfile } label: {
                HStack(spacing: 14) {
                    ZStack {
                        Circle().fill(Color.homeTint).frame(width: 52, height: 52)
                        Text(initials)
                            .font(.system(.title3, design: .rounded).weight(.semibold))
                            .foregroundStyle(Color.homeAccent)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(auth.displayName.isEmpty ? "Your name" : auth.displayName)
                            .font(.system(.headline, design: .serif))
                            .foregroundStyle(Color.homeAccentDeep)
                        if !auth.email.isEmpty {
                            Text(auth.email)
                                .font(.footnote)
                                .foregroundStyle(Color.homeSecondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.homeSecondary.opacity(0.6))
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
        } footer: {
            Text("Signed in with \(auth.provider.label) · Member since \(auth.createdAt.formatted(date: .abbreviated, time: .omitted))")
        }
    }

    private var securitySection: some View {
        Section("App lock") {
            if auth.lockEnabled {
                if auth.biometryAvailable {
                    Toggle(isOn: Binding(
                        get: { auth.biometricsEnabled },
                        set: { auth.setBiometricsEnabled($0) }
                    )) {
                        Label("Unlock with \(auth.biometryName)", systemImage: biometrySymbol)
                    }
                    .tint(.homeAccent)
                }
                Button { sheet = .passcode(.change) } label: {
                    Label("Change passcode", systemImage: "key")
                }
                Button { auth.lockNow(); dismiss() } label: {
                    Label("Lock now", systemImage: "lock")
                }
                Button(role: .destructive) { sheet = .passcode(.disable) } label: {
                    Label("Turn off passcode", systemImage: "lock.open")
                }
            } else {
                Button { sheet = .passcode(.enable) } label: {
                    Label("Turn on passcode", systemImage: "lock")
                }
                Text("Add a passcode to keep your journal private on this device.")
                    .font(.footnote)
                    .foregroundStyle(Color.homeSecondary)
            }
        }
        .tint(.homeAccent)
    }

    private var privacySection: some View {
        Section {
            Toggle(isOn: $insightsEnabled) {
                Label("AI insights", systemImage: "sparkles")
            }
            .tint(.homeAccent)
            Toggle(isOn: $assistEnabled) {
                Label("Writing help", systemImage: "hand.point.up.left")
            }
            .tint(.homeAccent)
        } header: {
            Text("Privacy")
        } footer: {
            Text("Insights sends a summary of recent entries to DeepSeek. Writing help sends the current entry when you pause, to suggest directions. Both off keep everything on-device.")
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: appVersion)
            Text("Lilac keeps your entries on this device. AI features (prompts, companion, Rewind) send text off-device only when enabled.")
                .font(.footnote)
                .foregroundStyle(Color.homeSecondary)
        }
    }

    private var accountSection: some View {
        Section {
            Button(role: .destructive) { showResetConfirm = true } label: {
                Label("Reset account", systemImage: "trash")
            }
        }
    }

    // MARK: Derived

    private var initials: String {
        let parts = auth.displayName.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first }.map(String.init).joined()
        return letters.isEmpty ? "🌱" : letters.uppercased()
    }

    private var biometrySymbol: String {
        auth.biometryType == .touchID ? "touchid" : "faceid"
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}

private enum SettingsSheet: Identifiable {
    case editProfile
    case passcode(PasscodeFlowSheet.Mode)

    var id: String {
        switch self {
        case .editProfile: return "editProfile"
        case .passcode(let mode): return "passcode-\(mode)"
        }
    }
}

// MARK: - Profile editing

private struct ProfileEditView: View {
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var email = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Your name", text: $name)
                        .textContentType(.name)
                }
                Section("Email") {
                    TextField("Email (optional)", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                }
            }
            .navigationTitle("Edit profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        auth.updateProfile(name: name, email: email)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                name = auth.displayName
                email = auth.email
            }
        }
        .tint(.homeAccent)
    }
}

// MARK: - Passcode flows (enable / change / disable)

struct PasscodeFlowSheet: View {
    enum Mode: CustomStringConvertible {
        case enable, change, disable
        var description: String {
            switch self {
            case .enable: return "enable"
            case .change: return "change"
            case .disable: return "disable"
            }
        }
    }

    let mode: Mode

    @EnvironmentObject private var auth: AuthManager
    @Environment(\.dismiss) private var dismiss

    private enum Stage { case verifyCurrent, choose, confirm }
    @State private var stage: Stage
    @State private var currentCode = ""
    @State private var firstCode = ""
    @State private var entry = ""
    @State private var errorText: String?
    @State private var shake: CGFloat = 0

    init(mode: Mode) {
        self.mode = mode
        _stage = State(initialValue: mode == .enable ? .choose : .verifyCurrent)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [.white, .homeBackgroundBottom],
                               startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

                VStack(spacing: 26) {
                    Spacer(minLength: 0)
                    VStack(spacing: 6) {
                        Text(title)
                            .font(.system(.title3, design: .serif).weight(.medium))
                            .foregroundStyle(Color.homeAccentDeep)
                        Text(errorText ?? subtitle)
                            .font(.subheadline)
                            .foregroundStyle(errorText != nil ? .red.opacity(0.85) : Color.homeSecondary)
                    }
                    PasscodePad(code: $entry, length: 4) { entered in
                        handle(entered)
                    }
                    .modifier(ShakeModifier(shake: shake))
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 32)
            }
            .navigationTitle("Passcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .tint(.homeAccent)
    }

    private var title: String {
        switch mode {
        case .enable: return "Set a passcode"
        case .change: return "Change passcode"
        case .disable: return "Turn off passcode"
        }
    }

    private var subtitle: String {
        switch stage {
        case .verifyCurrent: return "Enter your current passcode."
        case .choose: return "Choose a new 4-digit passcode."
        case .confirm: return "Enter it once more to confirm."
        }
    }

    private func handle(_ entered: String) {
        errorText = nil
        switch stage {
        case .verifyCurrent:
            if auth.verifyPasscode(entered) {
                currentCode = entered
                if mode == .disable {
                    _ = auth.disablePasscode(current: entered)
                    dismiss()
                } else {
                    advance(to: .choose)
                }
            } else {
                fail("Wrong passcode. Try again.")
            }
        case .choose:
            firstCode = entered
            advance(to: .confirm)
        case .confirm:
            if entered == firstCode {
                if mode == .enable {
                    auth.enablePasscode(firstCode, useBiometrics: auth.biometryAvailable)
                } else {
                    _ = auth.changePasscode(current: currentCode, new: firstCode)
                }
                dismiss()
            } else {
                firstCode = ""
                stage = .choose
                fail("That didn't match. Try again.")
            }
        }
    }

    private func advance(to next: Stage) {
        entry = ""
        stage = next
    }

    private func fail(_ message: String) {
        errorText = message
        entry = ""
        withAnimation(.linear(duration: 0.4)) { shake += 1 }
    }
}
