import SwiftUI

/// Email verification screen — step 2 of registration. The 6-digit code is
/// a real one-time code sent by Supabase Auth (AuthWelcomeView's Continue
/// button calls authService.startEmailRegistration(email:), which triggers
/// the email); `verify()` below checks it against Supabase for real.
///
/// Styled like Apple's own native verification-code screens: plain system
/// background, a grouped digit row instead of glass-over-photo boxes (whose
/// tint varied unpredictably depending on what photo content sat behind
/// each circle).
struct OTPVerificationView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    let fullName: String
    let email: String

    @State private var code = ""
    @FocusState private var isCodeFieldFocused: Bool
    @State private var secondsRemaining = 48
    @State private var didComplete = false
    @State private var isVerifying = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 6) {
                    Text("Verification")
                        .font(.brand(34))
                        .foregroundStyle(.white)
                    Text("Enter the code we sent to \(email)")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.appTextSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .padding(.top, 56)

                ZStack {
                    HStack(spacing: 10) {
                        ForEach(0..<6, id: \.self) { i in
                            digitBox(i)
                        }
                    }

                    // Invisible field capturing all input — a single field (rather
                    // than 6 fields cycling focus) is what lets iOS's one-time-code
                    // AutoFill actually fill the whole code in one tap.
                    TextField("", text: $code)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .focused($isCodeFieldFocused)
                        .foregroundStyle(.clear)
                        .tint(.clear)
                        .onChange(of: code) { _, newValue in
                            code = String(newValue.filter(\.isNumber).prefix(6))
                        }
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { isCodeFieldFocused = true }

                HStack(spacing: 4) {
                    Text("Didn't get a code?")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.appTextSecondary)
                    if secondsRemaining > 0 {
                        Text("Resend in \(String(format: "%02d:%02d", secondsRemaining / 60, secondsRemaining % 60))")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.appAccent)
                    } else {
                        Button("Resend") {
                            secondsRemaining = 48
                            Task { _ = await authService.startEmailRegistration(email: email) }
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.appAccent)
                    }
                }

                PrimaryButton(title: isVerifying ? "Verifying…" : "Continue", isEnabled: isCodeComplete && !isVerifying, color: .appAccentPurple) {
                    verify()
                }

                Spacer(minLength: 24)
            }
            .screenPadding()
        }
        .background(Color.appBackground.ignoresSafeArea())
        .onAppear { isCodeFieldFocused = true }
        .onReceive(timer) { _ in
            if secondsRemaining > 0 { secondsRemaining -= 1 }
        }
        .navigationBarBackButtonHidden(didComplete)
        .alert("Verification error", isPresented: Binding(get: { authService.authError != nil }, set: { if !$0 { authService.authError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(authService.authError ?? "")
        }
    }

    private var isCodeComplete: Bool { code.count == 6 }

    private func digitBox(_ index: Int) -> some View {
        let digit = index < code.count ? String(Array(code)[index]) : ""
        let isActive = isCodeFieldFocused && index == code.count
        return Text(digit)
            .multilineTextAlignment(.center)
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 44, height: 54)
            .background(Color.appSurface)
            .overlay(
                RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous)
                    .stroke(isActive ? Color.appAccentPurple : Color.appDivider, lineWidth: isActive ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
    }

    private func verify() {
        isVerifying = true
        Task {
            let success = await authService.verifyEmailCode(name: fullName, email: email, code: code)
            isVerifying = false
            if success { didComplete = true }
        }
    }
}

#Preview {
    NavigationStack {
        OTPVerificationView(fullName: "Artem", email: "artem@example.com")
    }
    .environmentObject(AuthService())
}
