import Foundation
import SwiftUI
import UIKit
import AuthenticationServices
import GoogleSignIn
import Supabase

enum AuthProvider: String {
    case apple, google, phone, email
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
/// see README.md for the one-time setup. Email registration (AuthWelcomeView
/// + OTPVerificationView) is real Supabase Auth: startEmailRegistration
/// sends a one-time code, verifyEmailCode checks it — no separate SMS
/// provider needed, unlike phone-based OTP.
@MainActor
final class AuthService: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: AuthUser?
    @Published var isAuthenticating = false
    @Published var authError: String?

    // MARK: - Sign in with Apple

    func signInWithApple() {
        authError = nil
        guard Self.isAppleSignInConfigured else {
            authError = "Sign in with Apple needs a paid Apple Developer Program membership on this project's team — a free/personal team can't provision that capability. Try email instead, or re-enable the com.apple.developer.applesignin entitlement once the project has a paid team."
            return
        }
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
        guard Self.isGoogleSignInConfigured else {
            authError = "Google Sign-In isn't configured yet — it needs a real client ID from your own Google Cloud project (see README.md). Try email or Apple instead."
            return
        }
        guard let presenter = Self.rootViewController() else {
            authError = "No window to present Google Sign-In from."
            return
        }
        isAuthenticating = true
        GIDSignIn.sharedInstance.signIn(withPresenting: presenter) { [weak self] result, error in
            Task { @MainActor in
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
    }

    /// Call from `.onAppear` on launch to silently resume a Google session.
    func restorePreviousGoogleSignIn() {
        guard Self.isGoogleSignInConfigured else { return }
        GIDSignIn.sharedInstance.restorePreviousSignIn { [weak self] user, _ in
            Task { @MainActor in
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
    }

    static func handle(_ url: URL) {
        GIDSignIn.sharedInstance.handle(url)
    }

    // MARK: - Email registration (real Supabase Auth, two-step: request code, verify)

    /// Step 1: sends a one-time code to `email` via Supabase Auth. Works
    /// with no extra provider setup (unlike phone/SMS, which needs a paid
    /// SMS provider configured in the Supabase dashboard).
    func startEmailRegistration(email: String) async -> Bool {
        authError = nil
        isAuthenticating = true
        defer { isAuthenticating = false }
        do {
            try await Self.withHostRetry { try await supabase.auth.signInWithOTP(email: email) }
            return true
        } catch {
            authError = Self.friendlyMessage(for: error)
            return false
        }
    }

    /// Step 2: verifies the code the member typed in. On success this is a
    /// real, signed-in Supabase Auth session (not a local-only demo).
    func verifyEmailCode(name: String, email: String, code: String) async -> Bool {
        authError = nil
        isAuthenticating = true
        defer { isAuthenticating = false }
        do {
            try await Self.withHostRetry { try await supabase.auth.verifyOTP(email: email, token: code, type: .email) }
            currentUser = AuthUser(
                id: email,
                name: name.trimmingCharacters(in: .whitespaces).isEmpty ? "Member" : name,
                email: email,
                provider: .email
            )
            isAuthenticated = true
            return true
        } catch {
            authError = Self.friendlyMessage(for: error)
            return false
        }
    }

    /// DNS lookups for a fresh hostname occasionally fail transiently
    /// (flaky Wi-Fi, a VPN that just connected/disconnected) and succeed a
    /// moment later — retry once after a short delay before surfacing an
    /// error, instead of making the member manually tap Continue again.
    private static func withHostRetry<T>(_ operation: () async throws -> T) async throws -> T {
        do {
            return try await operation()
        } catch {
            guard isHostNotFoundError(error) else { throw error }
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            return try await operation()
        }
    }

    private static func isHostNotFoundError(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCannotFindHost
    }

    private static func friendlyMessage(for error: Error) -> String {
        if isHostNotFoundError(error) {
            return "Can't reach the server. Check your internet connection — if you're on a VPN, try turning it off — then tap Continue again."
        }
        let description = error.localizedDescription
        if description.localizedCaseInsensitiveContains("rate limit") {
            return "Too many sign-in emails sent recently. Supabase's built-in test mailer only allows a couple of emails per hour per project — wait a few minutes and try again, or set up a custom SMTP provider in the Supabase dashboard (Authentication → Settings → SMTP Settings) to remove this limit."
        }
        return description
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        Task { try? await supabase.auth.signOut() }
        currentUser = nil
        isAuthenticated = false
    }

    /// True once a real reversed Google client ID (always prefixed
    /// `com.googleusercontent.apps.`) replaces the placeholder URL scheme
    /// in Info.plist. Checked before calling into GIDSignIn, which
    /// otherwise crashes the app outright — not a throwable error — when
    /// that URL scheme isn't registered.
    private static var isGoogleSignInConfigured: Bool {
        guard let urlTypes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] else { return false }
        let schemes = urlTypes.flatMap { ($0["CFBundleURLSchemes"] as? [String]) ?? [] }
        return schemes.contains { $0.hasPrefix("com.googleusercontent.apps.") }
    }

    /// CoreApp.entitlements currently has no `com.apple.developer.applesignin`
    /// key — a free/personal Apple Developer team can't create a device
    /// provisioning profile for that capability (Xcode error: "Personal
    /// development teams do not support the Sign In with Apple capability").
    /// Flip this to `true` and re-add the entitlement once the project has a
    /// paid Apple Developer Program team.
    private static let isAppleSignInConfigured = false

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
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let keyWindow = scenes.flatMap(\.windows).first(where: \.isKeyWindow) {
            return keyWindow
        }
        if let scene = scenes.first {
            return UIWindow(windowScene: scene)
        }
        return ASPresentationAnchor()
    }
}
