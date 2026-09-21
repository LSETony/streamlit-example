import SwiftUI

/// Email verification screen — step 2 of registration. The 6-digit code is
/// a real one-time code sent by Supabase Auth (AuthWelcomeView's Continue
/// button calls authService.startEmailRegistration(email:), which triggers
/// the email); `verify()` below checks it against Supabase for real.
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

    /// Card corner radius from the Figma source (82:97) — 45pt, matching
    /// AuthWelcomeView's card.
    private let cardCorner: CGFloat = 45

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                Image("OTPBackground")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .ignoresSafeArea()

                card(width: geo.size.width)
            }
        }
        .onAppear { isCodeFieldFocused = true }
        .onReceive(timer) { _ in
            if secondsRemaining > 0 { secondsRemaining -= 1 }
        }
        .navigationBarBackButtonHidden(didComplete)
    }

    private func card(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Verification")
                    .font(.brand(32))
                    .foregroundStyle(.white)
                Text("We've sent a code to \(Text(email).foregroundStyle(.white))")
                    .foregroundStyle(Color.appAccent)
                    .font(.brand(16))
                    .lineLimit(2)
            }
            .padding(.leading, width * 0.34)

            ZStack {
                GlassEffectContainer(spacing: 8) {
                    HStack(spacing: 8) {
                        ForEach(0..<6, id: \.self) { i in
                            digitBox(i)
                        }
                    }
                }

                // Invisible field capturing all input — a single field (rather
                // than 6 fields cycling focus) is what lets iOS's one-time-code
                // AutoFill actually fill the whole code in one tap; the earlier
                // per-box-TextField version could show the AutoFill suggestion
                // bar but never accept typed input.
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
                Text("Haven't received the code?")
                    .font(.brand(16))
                    .foregroundStyle(.white)
                if secondsRemaining > 0 {
                    let resendLabel = Text("Resend ").foregroundStyle(Color.appAccent)
                    let countdown = Text(String(format: "%02d:%02d", secondsRemaining / 60, secondsRemaining % 60))
                        .foregroundStyle(Color.appAccent)
                    Text("\(resendLabel)in \(countdown)")
                        .font(.brand(16))
                        .foregroundStyle(.white)
                } else {
                    Button("Resend") {
                        secondsRemaining = 48
                        Task { _ = await authService.startEmailRegistration(email: email) }
                    }
                    .font(.brand(16))
                    .foregroundStyle(Color.appAccent)
                }
            }
            .fixedSize(horizontal: false, vertical: true)

            PrimaryButton(title: isVerifying ? "Verifying…" : "Continue", isEnabled: isCodeComplete && !isVerifying, color: .appAccentPurple) {
                verify()
            }
        }
        .padding(24)
        .padding(.bottom, 12)
        .background(.black.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: cardCorner, style: .continuous))
    }

    private var isCodeComplete: Bool { code.count == 6 }

    private func digitBox(_ index: Int) -> some View {
        let digit = index < code.count ? String(Array(code)[index]) : ""
        let isActive = isCodeFieldFocused && index == code.count
        return Text(digit)
            .multilineTextAlignment(.center)
            .font(.brand(22))
            .foregroundStyle(.white)
            .frame(width: 42, height: 52)
            .glassEffect(
                isActive ? .regular.tint(.appAccentPurple).interactive() : .regular.interactive(),
                in: Circle()
            )
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
