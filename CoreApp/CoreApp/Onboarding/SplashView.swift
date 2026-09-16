import SwiftUI

/// Matches the "core." title-card frames ("Slide 16:9 - 1", "iPhone ... - 1/2/3") that open
/// the Figma flow: full-bleed dark background with the wordmark centered.
struct SplashView: View {
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            Text("core.")
                .font(Theme.Typeface.display(48, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}
