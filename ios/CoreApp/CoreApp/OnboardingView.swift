import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    var onFinish: () -> Void

    @State private var step = 0
    @State private var name: String = ""

    private let totalSteps = 3

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                ForEach(0..<totalSteps, id: \.self) { i in
                    Capsule()
                        .fill(i <= step ? Color.appAccent : Color.white.opacity(0.12))
                        .frame(height: 4)
                }
            }
            .padding(.top, 24)
            .screenPadding()

            Spacer()

            Group {
                switch step {
                case 0: welcomeStep
                case 1: nameStep
                default: readyStep
                }
            }
            .screenPadding()
            .transition(.opacity)

            Spacer()

            PrimaryButton(title: step == totalSteps - 1 ? "Enter core." : "Continue") {
                if step == totalSteps - 1 {
                    if !name.trimmingCharacters(in: .whitespaces).isEmpty {
                        appState.userName = name
                    }
                    onFinish()
                } else {
                    withAnimation { step += 1 }
                }
            }
            .screenPadding()
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground.ignoresSafeArea())
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 4) {
                Text("core").font(.system(size: 34, weight: .bold))
                Circle().fill(Color.appAccent).frame(width: 8, height: 8).offset(y: 6)
            }
            .foregroundStyle(.white)
            Text("Your club, your body, one app.")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
            Text("Book zones, follow your training plan, track nutrition and diagnostics — all synced with the club in real time.")
                .font(.system(size: 15))
                .foregroundStyle(.appTextSecondary)
        }
    }

    private var nameStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What should we call you?")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
            TextField("Your name", text: $name)
                .textFieldStyle(.plain)
                .font(.system(size: 18))
                .foregroundStyle(.white)
                .padding(16)
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
        }
    }

    private var readyStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("You're all set.")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
            Text("We've loaded a sample training plan, nutrition targets and your membership pass so you can explore core. right away.")
                .font(.system(size: 15))
                .foregroundStyle(.appTextSecondary)
        }
    }
}

#Preview {
    OnboardingView(onFinish: {})
        .environmentObject(AppState())
}
