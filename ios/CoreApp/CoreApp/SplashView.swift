import SwiftUI

/// The launch splash — matches the exact "core." logo asset from the design
/// export on a solid dark background, nothing else. The only animation is a
/// single tasteful entrance (fade + scale) into that exact static frame.
struct SplashView: View {
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            Image("CoreLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 220)
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
