import Foundation
import SwiftUI
import UIKit
import AuthenticationServices
import GoogleSignIn

enum AuthProvider: String {
    case apple, google, phone
}

struct AuthUser {
    var id: String
    var name: String
    var email: String?
    var provider: AuthProvider
}

/// Drives the sign-in flow. Apple Sign-In is fully native (AuthenticationServices)
/// and needs only the "Sign in with Apple" capability enabled on the target.
/// Google Sign-In is wired to the real GoogleSignIn SDK, but — like any OAuth
/// provider — needs a client ID issued by *your own* Google Cloud project;
/// see README.md for the one-time setup. Phone entry is a UI-complete demo:
/// wire `completePhoneSignIn` to a real OTP backend (e.g. Firebase Phone Auth)
/// to send actual SMS codes.
@MainActor
final class AuthService: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: AuthUser?
    @Published var isAuthenticating = false
    @Published var authError: String?

    // MARK: - Sign in with Apple

    func signInWithApple() {
        authError = nil
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        isAuthenticating = true
        controller.performRequests()
    }

    // MARK: - Google Sign-In

    func signInWithGoogle() {
        authError = nil
        guard let presenter = Self.rootViewController() else {
            authError = "No window to present Google Sign-In from."
            return
        }
        isAuthenticating = true
        GIDSignIn.sharedInstance.signIn(withPresenting: presenter) { [weak self] result, error in
            guard let self else { return }
            self.isAuthenticating = false
            if let error {
                // Cancellation is a normal outcome, not an error to surface.
                if (error as NSError).code != GIDSignInError.canceled.rawValue {
                    self.authError = error.localizedDescription
                }
                return
            }
            guard let googleUser = result?.user else { return }
            let profile = googleUser.profile
            self.currentUser = AuthUser(
                id: googleUser.userID ?? UUID().uuidString,
                name: profile?.name ?? "Google member",
                email: profile?.email,
                provider: .google
            )
            self.isAuthenticated = true
        }
    }

    /// Call from `.onAppear` on launch to silently resume a Google session.
    func restorePreviousGoogleSignIn() {
        GIDSignIn.sharedInstance.restorePreviousSignIn { [weak self] user, _ in
            guard let self, let user else { return }
            let profile = user.profile
            self.currentUser = AuthUser(
                id: user.userID ?? UUID().uuidString,
                name: profile?.name ?? "Google member",
                email: profile?.email,
                provider: .google
            )
            self.isAuthenticated = true
        }
    }

    static func handle(_ url: URL) {
        GIDSignIn.sharedInstance.handle(url)
    }

    // MARK: - Phone (demo — see note above)

    func completePhoneSignIn(name: String, phone: String) {
        currentUser = AuthUser(
            id: phone,
            name: name.trimmingCharacters(in: .whitespaces).isEmpty ? "Member" : name,
            email: nil,
            provider: .phone
        )
        isAuthenticated = true
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        currentUser = nil
        isAuthenticated = false
    }

    private static func rootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
    }
}

extension AuthService: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        isAuthenticating = false
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }
        let fullName = [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")
        currentUser = AuthUser(
            id: credential.user,
            name: fullName.isEmpty ? "Apple member" : fullName,
            email: credential.email,
            provider: .apple
        )
        isAuthenticated = true
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        isAuthenticating = false
        let nsError = error as NSError
        if nsError.code != ASAuthorizationError.canceled.rawValue {
            authError = error.localizedDescription
        }
    }
}

extension AuthService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }
}
