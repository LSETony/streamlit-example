import SwiftUI

/// Shown once, right after the splash — only for a member RootView
/// recognizes as already signed in from a previous launch (see
/// AuthService's currentUser persistence) — so returning members get a
/// quick personal greeting instead of either being dropped silently into
/// the app or forced through sign-in again. A fresh sign-up doesn't see
/// this in the same session; it's specifically the "welcome back" moment.
///
/// Centered, width-constrained, single-line with a shrinking scale factor
/// on both lines — a first pass left these unconstrained and a long name
/// (or a long device locale's "Good afternoon!") could run past the
/// screen edge; this makes that impossible regardless of name length.
struct WelcomeBackView: View {
    let name: String
    var onFinished: () -> Void

    @State private var showGreeting = false
    @State private var showName = false

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: return "Good morning!"
        case 12..<18: return "Good afternoon!"
        default: return "Good evening!"
        }
    }

    var body: some View {
        ZStack {
            AuthBackground()

            VStack(spacing: 6) {
                Text(greeting)
                    .font(.brand(30))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .opacity(showGreeting ? 1 : 0)
                    .offset(y: showGreeting ? 0 : 12)
                Text(name)
                    .font(.brand(30))
                    .foregroundStyle(Color.appAccent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .opacity(showName ? 1 : 0)
                    .offset(y: showName ? 0 : 12)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, AppMetrics.screenPadding)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { showGreeting = true }
            withAnimation(.easeOut(duration: 0.5).delay(0.18)) { showName = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                onFinished()
            }
        }
    }
}

#Preview {
    WelcomeBackView(name: "Jarvis Kitsune") {}
}
