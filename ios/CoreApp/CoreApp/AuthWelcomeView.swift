import SwiftUI

struct AuthWelcomeView: View {
    @EnvironmentObject var authService: AuthService
    @State private var fullName: String = ""
    @State private var email: String = ""
    @State private var goToVerify = false
    @State private var isSendingCode = false

    private var canContinue: Bool { email.contains("@") && email.contains(".") }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    Image("AuthBackground")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .ignoresSafeArea()

                    card(width: geo.size.width)
                }
            }
            .navigationDestination(isPresented: $goToVerify) {
                OTPVerificationView(fullName: fullName, email: email)
            }
            .alert("Sign-in error", isPresented: Binding(get: { authService.authError != nil }, set: { if !$0 { authService.authError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(authService.authError ?? "")
            }
        }
    }

    /// Card corner radius from the Figma source (82:73) — 45pt, distinct
    /// from AppMetrics.cardCorner (30) used elsewhere in the app; this
    /// sign-in card is intentionally softer/rounder.
    private let cardCorner: CGFloat = 45

    private func card(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .center, spacing: 4) {
                Text("Welcome")
                    .font(.brand(32))
                    .foregroundStyle(.white)
                Text("Create an account")
                    .font(.brand(16))
                    .foregroundStyle(Color.appAccent)
            }
            .frame(maxWidth: .infinity)

            fieldRow(icon: "person.fill") {
                TextField("", text: $fullName, prompt: Text("Full name").foregroundStyle(.white.opacity(0.45)))
                    .font(.brand(18))
                    .foregroundStyle(.white)
                    .textInputAutocapitalization(.words)
            }

            fieldRow(icon: "envelope.fill") {
                TextField("", text: $email, prompt: Text("you@example.com").foregroundStyle(.white.opacity(0.45)))
                    .font(.brand(18))
                    .foregroundStyle(.white)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            if canContinue {
                PrimaryButton(title: isSendingCode ? "Sending…" : "Continue", isEnabled: !isSendingCode, color: .appAccentPurple) {
                    Task {
                        isSendingCode = true
                        let sent = await authService.startEmailRegistration(email: email)
                        isSendingCode = false
                        if sent { goToVerify = true }
                    }
                }
            }

            HStack(spacing: 12) {
                Rectangle().fill(Color.white.opacity(0.2)).frame(height: 1)
                Text("or").font(.brand(16)).foregroundStyle(Color.appAccent)
                Rectangle().fill(Color.white.opacity(0.2)).frame(height: 1)
            }

            GlassEffectContainer(spacing: 14) {
                HStack(spacing: 14) {
                    socialButton(systemImage: "g.circle.fill") {
                        authService.signInWithGoogle()
                    }
                    socialButton(systemImage: "apple.logo") {
                        authService.signInWithApple()
                    }
                }
            }

            if authService.isAuthenticating {
                HStack {
                    Spacer()
                    ProgressView().tint(.white)
                    Spacer()
                }
            }
        }
        .padding(24)
        .padding(.bottom, 12)
        .background(.black.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: cardCorner, style: .continuous))
    }

    private func fieldRow<Content: View>(icon: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.white.opacity(0.12))
                Image(systemName: icon).font(.system(size: 16)).foregroundStyle(.white)
            }
            .frame(width: 44, height: 44)
            content()
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(height: 72)
        .glassEffect(.regular, in: Capsule())
    }

    private func socialButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Capsule())
    }
}

#Preview {
    AuthWelcomeView()
        .environmentObject(AuthService())
}
