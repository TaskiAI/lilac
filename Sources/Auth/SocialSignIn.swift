import Foundation
import UIKit
import AuthenticationServices
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

/// A provider identity handed back to `AuthManager.signIn(with:...)`.
struct SocialCredential {
    let userID: String
    let name: String?
    let email: String?
}

enum SocialAuthError: LocalizedError {
    case failed
    case cancelled
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .failed: return "Sign-in didn't complete. Please try again."
        case .cancelled: return "Sign-in was cancelled."
        case .notConfigured:
            return "Google Sign-In isn't set up in this build. Add the GoogleSignIn pod and a client ID (see Podfile)."
        }
    }
}

// MARK: - Sign in with Apple (native, no third-party SDK)

/// Drives a Sign in with Apple request and bridges the delegate callbacks into
/// an `async` result. Requires the "Sign in with Apple" capability on the target.
final class AppleSignInCoordinator: NSObject {
    private var continuation: CheckedContinuation<SocialCredential, Error>?

    func signIn() async throws -> SocialCredential {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            controller.performRequests()
        }
    }
}

extension AppleSignInCoordinator: ASAuthorizationControllerDelegate {
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            continuation?.resume(throwing: SocialAuthError.failed)
            continuation = nil
            return
        }
        let name = [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")
        continuation?.resume(returning: SocialCredential(
            userID: credential.user,
            name: name.isEmpty ? nil : name,
            email: credential.email
        ))
        continuation = nil
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        if let authError = error as? ASAuthorizationError, authError.code == .canceled {
            continuation?.resume(throwing: SocialAuthError.cancelled)
        } else {
            continuation?.resume(throwing: error)
        }
        continuation = nil
    }
}

extension AppleSignInCoordinator: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.foregroundKeyWindow ?? ASPresentationAnchor()
    }
}

// MARK: - Sign in with Google (optional: needs the GoogleSignIn pod + client ID)

/// Mirrors the app's optional-dependency pattern (see ML Kit): fully functional
/// when the `GoogleSignIn` pod is installed and a `GIDClientID` is configured in
/// Info.plist; otherwise `isAvailable` is false and `signIn()` throws
/// `.notConfigured` so the UI can explain the setup step.
enum GoogleSignInCoordinator {
    #if canImport(GoogleSignIn)
    static let isAvailable = true

    @MainActor
    static func signIn() async throws -> SocialCredential {
        guard let presenter = UIApplication.shared.topViewController else {
            throw SocialAuthError.failed
        }
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
        let user = result.user
        return SocialCredential(
            userID: user.userID ?? UUID().uuidString,
            name: user.profile?.name,
            email: user.profile?.email
        )
    }
    #else
    static let isAvailable = false

    @MainActor
    static func signIn() async throws -> SocialCredential {
        throw SocialAuthError.notConfigured
    }
    #endif
}

// MARK: - UIKit lookups

extension UIApplication {
    /// The active foreground key window, for presentation anchors.
    var foregroundKeyWindow: UIWindow? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .keyWindow
    }

    /// The top-most presented view controller, for SDKs that present modally.
    var topViewController: UIViewController? {
        var top = foregroundKeyWindow?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}
