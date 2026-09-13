import SwiftUI

/// The launch splash — matches the plain reference exactly: a solid dark
/// background with the "core." wordmark centered, nothing else. The only
/// animation is a single tasteful entrance (fade + scale) into that exact
/// static frame.
struct SplashView: View {
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            Text("core.")
                .font(.brand(46))
                .foregroundStyle(.white)
                .scaleEffect(appeared ? 1 : 0.85)
                .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.75)) {
                appeared = true
            }
        }
    }
}

#Preview {
    SplashView()
}
