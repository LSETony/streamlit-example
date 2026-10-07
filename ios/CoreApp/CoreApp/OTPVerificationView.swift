import SwiftUI

/// Email verification screen — step 2 of registration. The code is a real
/// one-time code sent by Supabase Auth (AuthWelcomeView's Continue button
/// calls authService.startEmailRegistration(email:), which triggers the
/// email); `verify()` below checks it against Supabase for real. Length is
/// this project's configured OTP length (8 digits), not Supabase's 6-digit
/// default — codeLength is the single place to change if that's adjusted.
///
/// Shares AuthWelcomeView's AuthBackground glow so the two-step flow reads
/// as one screen rather than a jump from branded to plain system chrome.
/// The digit row itself stays a grouped box (not glass-over-photo boxes,
/// whose tint varied unpredictably depending on what photo content sat
/// behind each circle) — that lesson still holds even over a flat gradient.
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

    private let codeLength = 8

    var body: some View {
        ZStack {
            AuthBackground()
            ScrollView {
                VStack(spacing: 28) {
                    VStack(spacing: 10) {
                        Image(systemName: "envelope.badge.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(Color.appAccentPurple)
                        Text("Verification")
                            .font(.brand(34))
                            .foregroundStyle(.white)
                        Text("Enter the code we sent to \(email)")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.appTextSecondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    .padding(.top, 40)

                    ZStack {
                        HStack(spacing: 6) {
                            ForEach(0..<codeLength, id: \.self) { i in
                                digitBox(i)
                            }
                        }

                        // Invisible field capturing all input — a single field (rather
                        // than N fields cycling focus) is what lets iOS's one-time-code
                        // AutoFill actually fill the whole code in one tap.
                        TextField("", text: $code)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            .focused($isCodeFieldFocused)
                            .foregroundStyle(.clear)
                            .tint(.clear)
                            .onChange(of: code) { _, newValue in
                                code = String(newValue.filter(\.isNumber).prefix(codeLength))
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
                                startCountdown()
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
        }
        .onAppear { isCodeFieldFocused = true }
        .task { startCountdown() }
        .navigationBarBackButtonHidden(didComplete)
        .alert("Verification error", isPresented: Binding(get: { authService.authError != nil }, set: { if !$0 { authService.authError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(authService.authError ?? "")
        }
    }

    private var isCodeComplete: Bool { code.count == codeLength }

    private func digitBox(_ index: Int) -> some View {
        let digit = index < code.count ? String(Array(code)[index]) : ""
        let isActive = isCodeFieldFocused && index == code.count
        return Text(digit)
            .multilineTextAlignment(.center)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 34, height: 46)
            .background(Color.appSurface)
            .overlay(
                RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous)
                    .stroke(isActive ? Color.appAccentPurple : Color.appDivider, lineWidth: isActive ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
    }

    /// Ticks `secondsRemaining` down once a second until it hits 0, then
    /// stops — replaces a Combine `Timer.publish(...).autoconnect()`
    /// stored as a property, which newer Swift's strict concurrency
    /// checking rejects (Publishers.Autoconnect isn't Sendable). Re-called
    /// from the Resend button to restart the countdown; never overlaps
    /// with a previous run since Resend only appears once this loop has
    /// already finished.
    private func startCountdown() {
        Task {
            while secondsRemaining > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard secondsRemaining > 0 else { break }
                secondsRemaining -= 1
            }
        }
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
