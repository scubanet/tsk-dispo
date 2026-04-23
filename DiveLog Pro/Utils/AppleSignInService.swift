import Foundation
import AuthenticationServices
import SwiftUI

// ═══════════════════════════════════════
// MARK: - Apple Sign-In Service
// ═══════════════════════════════════════
//
// Observable wrapper around ASAuthorizationAppleIDProvider. Handles:
//
//   • First-time sign-in (Apple gives us name/email ONCE — we persist both
//     to Keychain immediately; next time only .user comes back)
//   • Credential-state refresh on launch (.revoked → wipe keychain, force
//     user back to SignInView)
//   • Sign-out (local keychain wipe; Apple itself doesn't support an
//     app-initiated revoke, user must do that in Settings)
//
@Observable
@MainActor
final class AppleSignInService: NSObject {

    // ── Published state ──────────────────────
    var currentUserID: String?
    var currentEmail: String?
    var currentFullName: String?
    var lastError: String?

    var isSignedIn: Bool { currentUserID != nil }

    // ── Singleton (small, app-wide state) ────
    static let shared = AppleSignInService()

    override init() {
        super.init()
        // Re-hydrate from Keychain on launch.
        self.currentUserID   = KeychainHelper.read(key: .appleUserID)
        self.currentEmail    = KeychainHelper.read(key: .appleUserEmail)
        self.currentFullName = KeychainHelper.read(key: .appleUserFullName)
    }

    // ═══════════════════════════════════════
    // MARK: - Sign in
    // ═══════════════════════════════════════

    /// Kick off the Apple Sign-In flow. Resolves once Apple's sheet closes.
    /// The completion closure receives the persisted credential on success.
    func signIn() async throws -> AppleCredential {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])

        return try await withCheckedThrowingContinuation { cont in
            let delegate = SignInDelegate { result in
                switch result {
                case .success(let cred):
                    self.persist(credential: cred)
                    cont.resume(returning: cred)
                case .failure(let err):
                    self.lastError = err.localizedDescription
                    cont.resume(throwing: err)
                }
            }
            // Retain the delegate until the callback fires.
            self.activeDelegate = delegate
            controller.delegate = delegate
            controller.presentationContextProvider = delegate
            controller.performRequests()
        }
    }

    /// Check with Apple whether our stored credential is still valid. Call
    /// this on app launch — if the user revoked access via iOS Settings
    /// we wipe everything and force them back to SignInView.
    func refreshCredentialState() async {
        guard let uid = currentUserID else { return }
        let provider = ASAuthorizationAppleIDProvider()
        do {
            let state = try await provider.credentialState(forUserID: uid)
            switch state {
            case .authorized:
                break // all good, keep session
            case .revoked, .notFound:
                await MainActor.run { self.signOutLocal() }
            case .transferred:
                break
            @unknown default:
                break
            }
        } catch {
            // Network or framework error — keep existing session, don't
            // log out aggressively.
            #if DEBUG
            print("[AppleSignIn] credentialState failed: \(error)")
            #endif
        }
    }

    // ═══════════════════════════════════════
    // MARK: - Sign out / account delete
    // ═══════════════════════════════════════

    /// Local-only sign-out. Wipes Keychain + in-memory state.
    /// Apple doesn't support an app-initiated revoke — user removes us via
    /// Settings → Apple-ID → Sign in with Apple.
    func signOutLocal() {
        KeychainHelper.wipeAuth()
        currentUserID = nil
        currentEmail = nil
        currentFullName = nil
    }

    // ═══════════════════════════════════════
    // MARK: - Persistence
    // ═══════════════════════════════════════

    private func persist(credential: AppleCredential) {
        KeychainHelper.save(credential.userID, forKey: .appleUserID)
        currentUserID = credential.userID

        if let email = credential.email, !email.isEmpty {
            KeychainHelper.save(email, forKey: .appleUserEmail)
            currentEmail = email
        }
        if let name = credential.fullName, !name.isEmpty {
            KeychainHelper.save(name, forKey: .appleUserFullName)
            currentFullName = name
        }
    }

    // ── Delegate retention ───────────────────
    // ASAuthorizationController holds delegate weakly, so we must keep a
    // strong reference on the service.
    private var activeDelegate: SignInDelegate?
}

// ═══════════════════════════════════════
// MARK: - Credential payload
// ═══════════════════════════════════════

struct AppleCredential {
    let userID: String
    let email: String?
    let fullName: String?
    let identityToken: Data?
}

// ═══════════════════════════════════════
// MARK: - ASAuthorizationController delegate
// ═══════════════════════════════════════

private final class SignInDelegate: NSObject,
                                    ASAuthorizationControllerDelegate,
                                    ASAuthorizationControllerPresentationContextProviding {

    let completion: (Result<AppleCredential, Error>) -> Void

    init(completion: @escaping (Result<AppleCredential, Error>) -> Void) {
        self.completion = completion
        super.init()
    }

    // ── Delegate ─────────────────────────────

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let apple = authorization.credential as? ASAuthorizationAppleIDCredential else {
            completion(.failure(SignInError.invalidCredentialType))
            return
        }

        let fullName: String? = {
            guard let nc = apple.fullName else { return nil }
            let parts = [nc.givenName, nc.familyName].compactMap { $0 }.filter { !$0.isEmpty }
            return parts.isEmpty ? nil : parts.joined(separator: " ")
        }()

        let cred = AppleCredential(
            userID: apple.user,
            email: apple.email,
            fullName: fullName,
            identityToken: apple.identityToken
        )
        completion(.success(cred))
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        completion(.failure(error))
    }

    // ── Presentation context ─────────────────

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        if let window = scenes.flatMap(\.windows).first(where: { $0.isKeyWindow })
            ?? scenes.first?.windows.first {
            return window
        }
        return UIWindow(windowScene: scenes.first!)
    }

    // ── Errors ───────────────────────────────

    enum SignInError: LocalizedError {
        case invalidCredentialType

        var errorDescription: String? {
            switch self {
            case .invalidCredentialType:
                return "Unexpected credential type returned by Apple."
            }
        }
    }
}
