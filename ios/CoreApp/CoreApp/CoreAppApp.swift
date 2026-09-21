import SwiftUI

@main
struct CoreAppApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var authService = AuthService()

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

/// Launch flow: splash, then sign-in, then onboarding, then the app.
struct RootView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var appState: AppState
    @State private var showSplash = true

    var body: some View {
        Group {
            if showSplash {
                SplashView()
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
        .animation(.easeInOut, value: appState.hasCompletedOnboarding)
        .animation(.easeInOut, value: authService.isAuthenticated)
        .onAppear {
            authService.restorePreviousGoogleSignIn()
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
