import SwiftUI

/// The launch splash — shown briefly while the app checks for a resumable
/// sign-in session, matching the plain wordmark-on-black loading screen.
struct SplashView: View {
    @State private var pulse = false

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            HStack(spacing: 2) {
                Text("core")
                    .font(.system(size: 34, weight: .heavy))
                    .foregroundStyle(.white)
                Circle()
                    .fill(Color.white)
                    .frame(width: 8, height: 8)
                    .offset(y: 8)
            }
            .opacity(pulse ? 1 : 0.55)
            .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)

            VStack {
                Spacer()
                Capsule()
                    .fill(Color.white.opacity(0.25))
                    .frame(height: 3)
                    .padding(.horizontal, 0)
                    .frame(maxWidth: .infinity)
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .onAppear { pulse = true }
    }
}

#Preview {
    SplashView()
}
