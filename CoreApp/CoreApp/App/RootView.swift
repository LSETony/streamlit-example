import SwiftUI

private enum Phase {
    case splash, onboarding, main
}

/// Drives the top-level flow: splash ("core.") → 4-step onboarding → main app (Home hub).
struct RootView: View {
    @State private var phase: Phase = .splash

    var body: some View {
        ZStack {
            switch phase {
            case .splash:
                SplashView()
                    .transition(.opacity)
            case .onboarding:
                OnboardingFlow { phase = .main }
                    .transition(.opacity)
            case .main:
                HomeView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: phase)
        .task {
            try? await Task.sleep(for: .seconds(1.2))
            phase = .onboarding
        }
    }
}
