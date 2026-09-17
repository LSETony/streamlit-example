import SwiftUI

/// Phone verification screen. The UI (code boxes, resend cooldown) is fully
/// interactive; actually delivering an SMS needs a backend such as Firebase
/// Phone Auth or Twilio Verify — wire that into `verify()` below. Any 4-digit
/// code is accepted here so the flow can be demoed end-to-end.
struct OTPVerificationView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    let fullName: String
    let phoneDisplay: String

    @State private var digits: [String] = ["", "", "", ""]
    @FocusState private var focusedIndex: Int?
    @State private var secondsRemaining = 48
    @State private var didComplete = false

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
                    .font(.brand(26))
                    .foregroundStyle(.white)
                (Text("Отправили код на ") + Text(phoneDisplay).foregroundStyle(Color.appAccent))
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.6))
            }

            GlassEffectContainer(spacing: 16) {
                HStack(spacing: 16) {
                    ForEach(0..<4, id: \.self) { i in
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
                    Text("Отправить через ")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.6))
                    + Text(String(format: "%02d:%02d", secondsRemaining / 60, secondsRemaining % 60))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.appAccent)
                } else {
                    Button("Отправить") { secondsRemaining = 48 }
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.appAccent)
                }
            }

            PrimaryButton(title: "Continue", isEnabled: isCodeComplete, color: .appAccentPurple) {
                verify()
            }
        }
        .padding(24)
        .padding(.bottom, 12)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
    }

    private var isCodeComplete: Bool { digits.allSatisfy { $0.count == 1 } }

    private func digitBox(_ index: Int) -> some View {
        TextField("", text: Binding(
            get: { digits[index] },
            set: { newValue in
                let filtered = newValue.filter(\.isNumber)
                digits[index] = String(filtered.suffix(1))
                if !digits[index].isEmpty, index < 3 {
                    focusedIndex = index + 1
                } else if digits[index].isEmpty, index > 0 {
                    focusedIndex = index - 1
                }
            }
        ))
        .keyboardType(.numberPad)
        .multilineTextAlignment(.center)
        .font(.system(size: 22, weight: .bold))
        .foregroundStyle(.white)
        .frame(width: 60, height: 60)
        .glassEffect(
            focusedIndex == index ? .regular.tint(.appAccentPurple).interactive() : .regular.interactive(),
            in: Circle()
        )
        .focused($focusedIndex, equals: index)
    }

    private func verify() {
        didComplete = true
        authService.completePhoneSignIn(name: fullName, phone: phoneDisplay)
    }
}

#Preview {
    NavigationStack {
        OTPVerificationView(fullName: "Artem", phoneDisplay: "+7 485 478 00 56")
    }
    .environmentObject(AuthService())
}
