import SwiftUI

/// Sign-up/sign-in entry screen. A conventional centered form over
/// AuthBackground's hero workout video. Apple's own "Sign in with Apple"
/// button keeps its required spec (white fill, black text/logo); Google's
/// button is restyled to match it as a matched white pill pair — Google
/// doesn't mandate a specific button look the way Apple does — with
/// Google's actual brand blue on the "G" instead of the app's accent
/// color, since a stray red-orange "G" read as wrong for a Google button.
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
                    VStack(spacing: 26) {
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
                            Rectangle().fill(.white.opacity(0.25)).frame(height: 1)
                            Text("or").font(.system(size: 13)).foregroundStyle(.white.opacity(0.75))
                            Rectangle().fill(.white.opacity(0.25)).frame(height: 1)
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
        VStack(spacing: 10) {
            Text("core.")
                .font(.brand(40))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.5), radius: 8, y: 2)

            Text("Sign in or create your account")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.85))
                .shadow(color: .black.opacity(0.5), radius: 6, y: 1)
        }
        .padding(.top, 40)
    }

    private func authField(
        icon: String, placeholder: LocalizedStringKey, text: Binding<String>, field: Field,
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
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        // A dark tint (not plain .regular glass) so the field stays
        // clearly legible regardless of how bright the video behind it
        // is at any given moment — plain .regular glass over a face
        // close-up washed out almost to invisible.
        .glassEffect(.regular.tint(.black.opacity(0.45)), in: RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous)
                .stroke(focusedField == field ? Color.appAccentPurple : .white.opacity(0.12), lineWidth: focusedField == field ? 1.5 : 1)
        )
        .animation(.easeOut(duration: 0.2), value: focusedField)
    }

    /// Apple's own Sign in with Apple button spec: white fill, black text/logo.
    private func appleButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "apple.logo").font(.system(size: 19, weight: .medium))
                Text("Sign in with Apple").font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
        }
        .buttonStyle(.plain)
        .shadow(color: .black.opacity(0.3), radius: 12, y: 5)
    }

    /// Matches appleButton's white-pill shape instead of the previous dark
    /// glass treatment — the two looked mismatched side by side, and a
    /// stray glass tile over a busy video backdrop was harder to read than
    /// a plain white pill. "G" uses Google's actual brand blue.
    private func googleButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text("G")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(Color(red: 0.26, green: 0.52, blue: 0.96))
                Text("Sign in with Google").font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
        }
        .buttonStyle(.plain)
        .shadow(color: .black.opacity(0.3), radius: 12, y: 5)
    }
}

#Preview {
    AuthWelcomeView()
        .environmentObject(AuthService())
        .environmentObject(AppState())
}
