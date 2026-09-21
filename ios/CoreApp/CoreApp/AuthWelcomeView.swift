import SwiftUI

/// Sign-up entry screen, styled after Apple's own native account-creation
/// forms (Apple ID setup, App Store sign-in): plain system background,
/// a grouped list-style field group, and HIG-correct Apple/Google buttons —
/// rather than a photo backdrop with glass panels, which was fragile (ghost
/// bars where glass shapes merged, uneven refraction over busy photo areas).
struct AuthWelcomeView: View {
    @EnvironmentObject var authService: AuthService
    @State private var fullName: String = ""
    @State private var email: String = ""
    @State private var goToVerify = false
    @State private var isSendingCode = false

    private var canContinue: Bool { email.contains("@") && email.contains(".") }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    VStack(spacing: 6) {
                        Text("Welcome")
                            .font(.brand(34))
                            .foregroundStyle(.white)
                        Text("Create your core. account")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.appTextSecondary)
                    }
                    .padding(.top, 56)

                    VStack(spacing: 0) {
                        TextField("", text: $fullName, prompt: Text("Full name").foregroundStyle(Color.appTextSecondary))
                            .font(.system(size: 17))
                            .foregroundStyle(.white)
                            .textInputAutocapitalization(.words)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)

                        AppDivider().padding(.leading, 16)

                        TextField("", text: $email, prompt: Text("Email").foregroundStyle(Color.appTextSecondary))
                            .font(.system(size: 17))
                            .foregroundStyle(.white)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                    }
                    .background(Color.appSurface)
                    .clipShape(RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))

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
            }
            .background(Color.appBackground.ignoresSafeArea())
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
            .background(Color.appSurface)
            .overlay(
                RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous)
                    .stroke(Color.appDivider, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AuthWelcomeView()
        .environmentObject(AuthService())
}
