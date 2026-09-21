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

                    card
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

    private var card: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                Text("Sign in or create account")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.appAccent)
            }

            fieldRow(icon: "person.fill") {
                TextField("", text: $fullName, prompt: Text("Full name").foregroundStyle(.white.opacity(0.45)))
                    .foregroundStyle(.white)
                    .textInputAutocapitalization(.words)
            }

            fieldRow(icon: "envelope.fill") {
                TextField("", text: $email, prompt: Text("you@example.com").foregroundStyle(.white.opacity(0.45)))
                    .font(.brand(16))
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
                Text("OR").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.appAccent)
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
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
    }

    private func fieldRow<Content: View>(icon: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.white.opacity(0.12))
                Image(systemName: icon).font(.system(size: 14)).foregroundStyle(.white)
            }
            .frame(width: 36, height: 36)
            content()
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
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
