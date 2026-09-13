import SwiftUI

@main
struct CoreAppApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
        }
    }
}

/// Decides whether to show onboarding or the main tab experience.
struct RootView: View {
    @EnvironmentObject var appState: AppState
    @State private var hasOnboarded = false

    var body: some View {
        Group {
            if hasOnboarded {
                ContentView()
                    .transition(.opacity)
            } else {
                OnboardingView(onFinish: {
                    withAnimation(.easeInOut) { hasOnboarded = true }
                })
                .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: hasOnboarded)
    }
}
