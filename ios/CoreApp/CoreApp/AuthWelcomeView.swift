import SwiftUI

private let countryCodes: [(flag: String, code: String)] = [
    ("🇷🇺", "+7"), ("🇺🇸", "+1"), ("🇬🇧", "+44"), ("🇩🇪", "+49"), ("🇦🇪", "+971"),
]

struct AuthWelcomeView: View {
    @EnvironmentObject var authService: AuthService
    @State private var fullName: String = ""
    @State private var phone: String = ""
    @State private var countryCode: String = "+7"
    @State private var goToVerify = false

    private var canContinue: Bool { phone.filter(\.isNumber).count >= 7 }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Image("AuthBackground")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()

                card
            }
            .navigationDestination(isPresented: $goToVerify) {
                OTPVerificationView(fullName: fullName, phoneDisplay: "\(countryCode) \(phone)")
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
                Text("Добро пожаловать")
                    .font(.brand(28))
                    .foregroundStyle(.white)
                Text("Создать аккаунт")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.appAccent)
            }

            fieldRow(icon: "person.fill") {
                TextField("", text: $fullName, prompt: Text("ФИО").foregroundStyle(.white.opacity(0.45)))
                    .foregroundStyle(.white)
                    .textInputAutocapitalization(.words)
            }

            fieldRow(icon: "phone.fill") {
                Menu {
                    ForEach(countryCodes, id: \.code) { item in
                        Button("\(item.flag) \(item.code)") { countryCode = item.code }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(countryCode).foregroundStyle(.white)
                        Image(systemName: "chevron.down").font(.system(size: 10)).foregroundStyle(.white.opacity(0.6))
                    }
                }
                Divider().frame(height: 20).overlay(Color.white.opacity(0.2))
                TextField("", text: $phone, prompt: Text("485 478 00 56").foregroundStyle(.white.opacity(0.45)))
                    .foregroundStyle(.white)
                    .keyboardType(.phonePad)
            }

            if canContinue {
                PrimaryButton(title: "Continue", color: .appAccentPurple) { goToVerify = true }
            }

            HStack(spacing: 12) {
                Rectangle().fill(Color.white.opacity(0.2)).frame(height: 1)
                Text("или").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.5))
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
