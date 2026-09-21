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

    @State private var digits: [String] = Array(repeating: "", count: 6)
    @FocusState private var focusedIndex: Int?
    @State private var secondsRemaining = 48
    @State private var didComplete = false
    @State private var isVerifying = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack(alignment: .bottom) {
            Image("OTPBackground")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            card
        }
        .onAppear { focusedIndex = 0 }
        .onReceive(timer) { _ in
            if secondsRemaining > 0 { secondsRemaining -= 1 }
        }
        .navigationBarBackButtonHidden(didComplete)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Верификация")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                (Text("Отправили код на ").foregroundStyle(Color.appAccent) + Text(email).foregroundStyle(.white))
                    .font(.system(size: 14))
            }

            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 10) {
                    ForEach(0..<6, id: \.self) { i in
                        digitBox(i)
                    }
                }
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 4) {
                Text("Не пришел код?")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.6))
                if secondsRemaining > 0 {
                    Text("Отправить ")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.appAccent)
                    + Text("через ")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.6))
                    + Text(String(format: "%02d:%02d", secondsRemaining / 60, secondsRemaining % 60))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.appAccent)
                } else {
                    Button("Отправить") {
                        secondsRemaining = 48
                        Task { _ = await authService.startEmailRegistration(email: email) }
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.appAccent)
                }
            }

            PrimaryButton(title: isVerifying ? "Проверяем…" : "Continue", isEnabled: isCodeComplete && !isVerifying, color: .appAccentPurple) {
                verify()
            }
        }
        .padding(24)
        .padding(.bottom, 12)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
    }

    private var isCodeComplete: Bool { digits.allSatisfy { $0.count == 1 } }
    private var code: String { digits.joined() }

    private func digitBox(_ index: Int) -> some View {
        TextField("", text: Binding(
            get: { digits[index] },
            set: { newValue in
                let filtered = newValue.filter(\.isNumber)
                digits[index] = String(filtered.suffix(1))
                if !digits[index].isEmpty, index < 5 {
                    focusedIndex = index + 1
                } else if digits[index].isEmpty, index > 0 {
                    focusedIndex = index - 1
                }
            }
        ))
        .keyboardType(.numberPad)
        .multilineTextAlignment(.center)
        .font(.brand(24))
        .foregroundStyle(.white)
        .frame(width: 46, height: 56)
        .glassEffect(
            focusedIndex == index ? .regular.tint(.appAccentPurple).interactive() : .regular.interactive(),
            in: Circle()
        )
        .focused($focusedIndex, equals: index)
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
