import Foundation
import SwiftUI
import CryptoKit
import LocalAuthentication

/// Owns the local account and the app-lock state. There is no backend, so an
/// "account" is a name/email kept in `UserDefaults` and a passcode kept as a
/// salted SHA-256 hash in the Keychain; "login" is unlocking with that passcode
/// or Face ID / Touch ID.
@MainActor
final class AuthManager: ObservableObject {
    /// What the root view should show.
    enum Phase {
        case launching     // splash, before we've decided
        case needsAccount  // first run — create the local account
        case locked        // returning, app lock engaged
        case unlocked      // in the app
    }

    @Published private(set) var phase: Phase = .launching

    /// How the local account was established.
    enum AuthProvider: String {
        case local, apple, google

        var label: String {
            switch self {
            case .local: return "Passcode"
            case .apple: return "Apple"
            case .google: return "Google"
            }
        }
    }

    private let defaults = UserDefaults.standard
    private enum Key {
        static let name = "account.name"
        static let email = "account.email"
        static let createdAt = "account.createdAt"
        static let provider = "account.provider"
        static let providerID = "account.providerID"
        static let lockEnabled = "lock.enabled"
        static let biometricsEnabled = "lock.biometricsEnabled"
        static let passcode = "com.lilac.passcode"   // Keychain account
        static let salt = "com.lilac.passcode.salt"  // Keychain account
    }

    // MARK: Account state

    var displayName: String { defaults.string(forKey: Key.name) ?? "" }
    var email: String { defaults.string(forKey: Key.email) ?? "" }
    var hasAccount: Bool { defaults.object(forKey: Key.createdAt) != nil }
    var lockEnabled: Bool { defaults.bool(forKey: Key.lockEnabled) }
    var biometricsEnabled: Bool { defaults.bool(forKey: Key.biometricsEnabled) }
    var createdAt: Date { defaults.object(forKey: Key.createdAt) as? Date ?? .now }
    var provider: AuthProvider {
        AuthProvider(rawValue: defaults.string(forKey: Key.provider) ?? "") ?? .local
    }

    /// Decide the initial phase once the splash has shown.
    func bootstrap() {
        guard phase == .launching else { return }
        if !hasAccount {
            phase = .needsAccount
        } else if lockEnabled {
            phase = .locked
        } else {
            phase = .unlocked
        }
    }

    // MARK: Account creation

    func createAccount(name: String, email: String, passcode: String?, useBiometrics: Bool) {
        defaults.set(name.trimmingCharacters(in: .whitespaces), forKey: Key.name)
        defaults.set(email.trimmingCharacters(in: .whitespaces), forKey: Key.email)
        defaults.set(Date(), forKey: Key.createdAt)
        defaults.set(AuthProvider.local.rawValue, forKey: Key.provider)

        if let passcode, !passcode.isEmpty {
            storePasscode(passcode)
            defaults.set(true, forKey: Key.lockEnabled)
            defaults.set(useBiometrics && biometryAvailable, forKey: Key.biometricsEnabled)
        } else {
            defaults.set(false, forKey: Key.lockEnabled)
            defaults.set(false, forKey: Key.biometricsEnabled)
        }
        phase = .unlocked
    }

    /// Sign in (or up) with Apple / Google. Since there's no backend, the
    /// provider identity just seeds the local account. Name/email are only
    /// filled if the provider supplies them (Apple gives them once) and any
    /// previously stored values are preserved otherwise. Lock stays off until
    /// the writer sets a passcode in Settings.
    func signIn(with provider: AuthProvider, id: String, name: String?, email: String?) {
        if let name, !name.isEmpty { defaults.set(name, forKey: Key.name) }
        if let email, !email.isEmpty { defaults.set(email, forKey: Key.email) }
        defaults.set(provider.rawValue, forKey: Key.provider)
        defaults.set(id, forKey: Key.providerID)
        if !hasAccount {
            defaults.set(Date(), forKey: Key.createdAt)
            defaults.set(false, forKey: Key.lockEnabled)
            defaults.set(false, forKey: Key.biometricsEnabled)
        }
        phase = .unlocked
    }

    // MARK: Profile & security settings

    func updateProfile(name: String, email: String) {
        defaults.set(name.trimmingCharacters(in: .whitespaces), forKey: Key.name)
        defaults.set(email.trimmingCharacters(in: .whitespaces), forKey: Key.email)
        objectWillChange.send()
    }

    /// Turn on the passcode lock (from Settings). Returns nothing — always succeeds.
    func enablePasscode(_ code: String, useBiometrics: Bool) {
        storePasscode(code)
        defaults.set(true, forKey: Key.lockEnabled)
        defaults.set(useBiometrics && biometryAvailable, forKey: Key.biometricsEnabled)
        objectWillChange.send()
    }

    /// Change the passcode; requires the current one. Returns whether it changed.
    @discardableResult
    func changePasscode(current: String, new: String) -> Bool {
        guard verifyPasscode(current) else { return false }
        storePasscode(new)
        objectWillChange.send()
        return true
    }

    /// Turn off the passcode lock; requires the current passcode.
    @discardableResult
    func disablePasscode(current: String) -> Bool {
        guard verifyPasscode(current) else { return false }
        Keychain.delete(Key.passcode)
        Keychain.delete(Key.salt)
        defaults.set(false, forKey: Key.lockEnabled)
        defaults.set(false, forKey: Key.biometricsEnabled)
        objectWillChange.send()
        return true
    }

    func setBiometricsEnabled(_ enabled: Bool) {
        defaults.set(enabled && biometryAvailable && lockEnabled, forKey: Key.biometricsEnabled)
        objectWillChange.send()
    }

    /// Manually engage the lock now (Settings "Lock now"). No-op if no passcode.
    func lockNow() {
        if lockEnabled { phase = .locked }
    }

    // MARK: Locking / unlocking

    /// Re-engage the lock when leaving the app (called on scene background).
    func lockIfNeeded() {
        if lockEnabled, phase == .unlocked {
            phase = .locked
        }
    }

    func unlock() {
        phase = .unlocked
    }

    /// Wipe the passcode + account (an escape hatch for a forgotten passcode).
    /// Journal entries are not deleted — the writer re-creates their account and
    /// regains access.
    func resetAccount() {
        Keychain.delete(Key.passcode)
        Keychain.delete(Key.salt)
        [Key.name, Key.email, Key.createdAt, Key.lockEnabled, Key.biometricsEnabled]
            .forEach { defaults.removeObject(forKey: $0) }
        phase = .needsAccount
    }

    // MARK: Passcode

    func verifyPasscode(_ code: String) -> Bool {
        guard let stored = Keychain.read(Key.passcode) else { return false }
        return stored == hash(code)
    }

    private func storePasscode(_ code: String) {
        // Fresh random salt per passcode so the stored hash isn't a bare digest.
        let salt = Data((0..<16).map { _ in UInt8.random(in: .min ... .max) })
        Keychain.save(salt, for: Key.salt)
        Keychain.save(hash(code, salt: salt), for: Key.passcode)
    }

    private func hash(_ code: String, salt: Data? = nil) -> Data {
        let salt = salt ?? Keychain.read(Key.salt) ?? Data()
        var input = salt
        input.append(Data(code.utf8))
        return Data(SHA256.hash(data: input))
    }

    // MARK: Biometrics

    /// Whether the device offers Face ID / Touch ID at all.
    var biometryAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    var biometryType: LABiometryType {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return context.biometryType
    }

    /// A friendly name for the available biometry ("Face ID" / "Touch ID").
    var biometryName: String {
        switch biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        default: return "Biometrics"
        }
    }

    /// Prompt for Face ID / Touch ID. Returns whether it succeeded.
    func authenticateWithBiometrics() async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return false
        }
        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Unlock your journal"
            )
        } catch {
            return false
        }
    }
}
