import SwiftUI

/// The launch splash — a plain white "core." wordmark on black, with a
/// staggered letter reveal, a breathing scale loop, expanding sonar-style
/// rings, and an animated loading bar.
struct SplashView: View {
    private let letters = Array("core.")

    @State private var visibleCount = 0
    @State private var ringsExpanding = false
    @State private var breathing = false
    @State private var barProgress: CGFloat = 0.12

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            sonarRings

            HStack(spacing: 1) {
                ForEach(letters.indices, id: \.self) { i in
                    Text(String(letters[i]))
                        .font(.brand(46))
                        .foregroundStyle(.white)
                        .opacity(i < visibleCount ? 1 : 0)
                        .offset(y: i < visibleCount ? 0 : 16)
                        .scaleEffect(i < visibleCount ? 1 : 0.55)
                }
            }
            .scaleEffect(breathing ? 1.045 : 1.0)

            VStack {
                Spacer()
                loadingBar
                    .padding(.bottom, 56)
            }
        }
        .onAppear(perform: animateIn)
    }

    private var sonarRings: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(Color.white.opacity(0.14), lineWidth: 1.2)
                    .frame(
                        width: ringsExpanding ? 300 : 36,
                        height: ringsExpanding ? 300 : 36
                    )
                    .opacity(ringsExpanding ? 0 : 0.9)
                    .animation(
                        .easeOut(duration: 2.2)
                            .repeatForever(autoreverses: false)
                            .delay(Double(i) * 0.7),
                        value: ringsExpanding
                    )
            }
        }
    }

    private var loadingBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.12))
                Capsule()
                    .fill(Color.white)
                    .frame(width: geo.size.width * barProgress)
            }
        }
        .frame(width: 120, height: 3)
    }

    private func animateIn() {
        for i in 0...letters.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.07) {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.65)) {
                    visibleCount = i
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            ringsExpanding = true
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                breathing = true
            }
        }
        withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) {
            barProgress = 0.92
        }
    }
}

#Preview {
    SplashView()
}
