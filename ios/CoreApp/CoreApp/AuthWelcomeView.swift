import SwiftUI

/// Sign-up/sign-in entry screen. Keeps the HIG-correct Apple/Google button
/// specs from the previous pass (those aren't ours to restyle), but swaps
/// the plain system background and grouped-list fields for the app's own
/// language: AuthBackground's brand glow, a breathing ThinkingOrb mark,
/// and individual glass fields that light up on focus — so the very first
/// screen a member sees actually looks like core. instead of a generic
/// system form.
struct AuthWelcomeView: View {
    @EnvironmentObject var authService: AuthService
    @State private var fullName: String = ""
    @State private var email: String = ""
    @State private var goToVerify = false
    @State private var isSendingCode = false
    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case name, email }

    private var canContinue: Bool { email.contains("@") && email.contains(".") }

    var body: some View {
        NavigationStack {
            ZStack {
                AuthBackground()
                ScrollView {
                    VStack(spacing: 28) {
                        header

                        VStack(spacing: 10) {
                            authField(icon: "person.fill", placeholder: "Full name", text: $fullName, field: .name, autocap: .words)
                            authField(icon: "envelope.fill", placeholder: "Email", text: $email, field: .email, keyboard: .emailAddress, autocap: .never)
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
                            Rectangle().fill(Color.appDivider).frame(height: 1)
                            Text("or").font(.system(size: 13)).foregroundStyle(Color.appTextSecondary)
                            Rectangle().fill(Color.appDivider).frame(height: 1)
                        }

                        VStack(spacing: 12) {
                            appleButton { authService.signInWithApple() }
                            googleButton { authService.signInWithGoogle() }
                        }

                        if authService.isAuthenticating {
                            ProgressView().tint(.white)
                        }

                        Spacer(minLength: 24)
                    }
                    .screenPadding()
                    .padding(.top, 28)
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

    private var header: some View {
        VStack(spacing: 16) {
            ZStack {
                ThinkingOrb(size: 92, speed: 0.55)
                Circle()
                    .stroke(
                        LinearGradient(colors: [.white.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom),
                        lineWidth: 1
                    )
                    .frame(width: 92, height: 92)
            }

            VStack(spacing: 6) {
                Text("core.")
                    .font(.brand(38))
                    .foregroundStyle(.white)
                Text("Sign in or create your account")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.appTextSecondary)
            }
        }
        .padding(.top, 12)
    }

    private func authField(
        icon: String, placeholder: String, text: Binding<String>, field: Field,
        keyboard: UIKeyboardType = .default, autocap: TextInputAutocapitalization = .sentences
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(focusedField == field ? Color.appAccentPurple : Color.appTextSecondary)
                .frame(width: 18)
            TextField("", text: text, prompt: Text(placeholder).foregroundStyle(Color.appTextSecondary))
                .font(.system(size: 17))
                .foregroundStyle(.white)
                .keyboardType(keyboard)
                .textInputAutocapitalization(autocap)
                .autocorrectionDisabled(keyboard == .emailAddress)
                .focused($focusedField, equals: field)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous)
                .stroke(focusedField == field ? Color.appAccentPurple : .clear, lineWidth: 1.5)
        )
        .animation(.easeOut(duration: 0.2), value: focusedField)
    }

    /// Apple's own Sign in with Apple button spec: white fill, black text/logo.
    private func appleButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "apple.logo").font(.system(size: 18, weight: .medium))
                Text("Sign in with Apple").font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func googleButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text("G").font(.system(size: 18, weight: .bold)).foregroundStyle(Color.appAccent)
                Text("Sign in with Google").font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
    }
}

#Preview {
    AuthWelcomeView()
        .environmentObject(AuthService())
}
