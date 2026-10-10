import SwiftUI

/// Shown once, right after the splash — only for a member RootView
/// recognizes as already signed in from a previous launch (see
/// AuthService's currentUser persistence) — so returning members get a
/// quick personal greeting instead of either being dropped silently into
/// the app or forced through sign-in again. A fresh sign-up doesn't see
/// this in the same session; it's specifically the "welcome back" moment.
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
        ZStack(alignment: .bottomLeading) {
            AuthBackground()

            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(.brand(32))
                    .foregroundStyle(.white)
                    .opacity(showGreeting ? 1 : 0)
                    .offset(y: showGreeting ? 0 : 16)
                Text(name)
                    .font(.brand(32))
                    .foregroundStyle(.white)
                    .opacity(showName ? 1 : 0)
                    .offset(y: showName ? 0 : 16)
            }
            .padding(.horizontal, AppMetrics.screenPadding)
            .padding(.bottom, 72)
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
