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

/// Launch flow: splash, then sign-in (Google / Apple / phone), then the app.
struct RootView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var appState: AppState
    @State private var showSplash = true

    var body: some View {
        Group {
            if showSplash {
                SplashView()
                    .transition(.opacity)
            } else if authService.isAuthenticated {
                ContentView()
                    .transition(.opacity)
            } else {
                AuthWelcomeView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: showSplash)
        .animation(.easeInOut, value: authService.isAuthenticated)
        .onAppear {
            authService.restorePreviousGoogleSignIn()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                showSplash = false
            }
        }
        .onChange(of: authService.currentUser?.name) { _, newName in
            if let newName, !newName.isEmpty {
                appState.userName = newName
            }
        }
    }
}
