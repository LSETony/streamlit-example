import SwiftUI
import StripePaymentSheet

@main
struct CoreAppApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var authService = AuthService()

    init() {
        StripeAPI.defaultPublishableKey = StripeConfig.publishableKey
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(authService)
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    AuthService.handle(url)
                }
        }
    }
}

/// Gates the app behind sign-in: Apple, Google, or email (two-step
/// registration — AuthWelcomeView collects name + email and sends a code
/// via Supabase Auth, OTPVerificationView checks it). Flip to `false` to
/// skip straight to the app again.
let requiresSignIn = true

/// Launch flow: splash, then (if returning already signed in) a personal
/// welcome-back greeting, then sign-in if needed, then onboarding, then
/// the app. `showWelcomeBack` is captured once in the first `onAppear` —
/// before the splash timer flips `showSplash` to false — from whatever
/// `authService.isAuthenticated` already is at that instant. Since
/// AuthService restores a persisted sign-in synchronously in its own
/// `init()` (see AuthService.swift), that's true only for a member who
/// was already signed in on a previous launch, never for someone who
/// just finished AuthWelcomeView/OTPVerificationView in this same
/// session — so a fresh sign-up goes straight to onboarding/the app
/// without a redundant second "welcome" moment.
struct RootView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var appState: AppState
    @State private var showSplash = true
    @State private var showWelcomeBack = false

    var body: some View {
        Group {
            if showSplash {
                SplashView()
                    .transition(.opacity)
            } else if showWelcomeBack, let name = authService.currentUser?.name, !name.isEmpty {
                WelcomeBackView(name: name) {
                    withAnimation(.easeInOut) { showWelcomeBack = false }
                }
                .transition(.opacity)
            } else if requiresSignIn && !authService.isAuthenticated {
                AuthWelcomeView()
                    .transition(.opacity)
            } else if !appState.hasCompletedOnboarding {
                OnboardingView()
                    .transition(.opacity)
            } else {
                ContentView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: showSplash)
        .animation(.easeInOut, value: showWelcomeBack)
        .animation(.easeInOut, value: appState.hasCompletedOnboarding)
        .animation(.easeInOut, value: authService.isAuthenticated)
        .onAppear {
            showWelcomeBack = authService.isAuthenticated
            authService.restorePreviousGoogleSignIn()
            Task { await authService.validatePersistedSession() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                showSplash = false
            }
        }
        .onChange(of: authService.currentUser?.name) { _, newName in
            if let newName, !newName.isEmpty {
                appState.fullName = newName
            }
        }
    }
}
