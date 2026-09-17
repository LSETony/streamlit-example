import SwiftUI

/// The 4-step "tell us about yourself" wizard from the latest Figma pass:
/// gender, goal, contraindications, and experience level. Purely local
/// state — feeds `AppState` so a future personalization pass can read it.
struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var step: Int = 0

    private let totalSteps = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            header
            progressBar
            Group {
                switch step {
                case 0: genderStep
                case 1: goalStep
                case 2: contradictionsStep
                default: levelStep
                }
            }
            Spacer(minLength: 0)
            PrimaryButton(title: "Continue", isEnabled: canContinue, color: .appAccentPurple) {
                advance()
            }
        }
        .screenPadding()
        .padding(.top, 24)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.appBackground.ignoresSafeArea())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(step == 2 ? "Tell us about yourself" : stepTitle)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)
            Text("This tailor plans and your experience")
                .font(.system(size: 13))
                .foregroundStyle(Color.appTextSecondary)
        }
    }

    private var stepTitle: String {
        switch step {
        case 0: return "Tell us about yourself"
        case 1: return "What's your goal?"
        default: return "Choose your level"
        }
    }

    private var progressBar: some View {
        HStack(spacing: 10) {
            Capsule()
                .fill(Color.appTextSecondary.opacity(0.35))
                .frame(height: 6)
                .overlay(alignment: .leading) {
                    GeometryReader { geo in
                        Capsule()
                            .fill(Color.appAccent)
                            .frame(width: geo.size.width * (Double(step + 1) / Double(totalSteps)))
                    }
                }
            Text("\(step + 1)/\(totalSteps)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.appTextSecondary)
        }
    }

    private var canContinue: Bool {
        switch step {
        case 0: return appState.selectedGender != nil
        case 1: return appState.selectedGoal != nil
        case 2: return true
        default: return appState.selectedLevel != nil
        }
    }

    private func advance() {
        if step < totalSteps - 1 {
            step += 1
        } else {
            appState.hasCompletedOnboarding = true
        }
    }

    // MARK: Step 1 — gender

    private var genderStep: some View {
        VStack(spacing: 12) {
            optionRow(title: "Men", isSelected: appState.selectedGender == "Men") {
                appState.selectedGender = "Men"
            }
            optionRow(title: "Women", isSelected: appState.selectedGender == "Women") {
                appState.selectedGender = "Women"
            }
        }
    }

    // MARK: Step 2 — goal

    private var goalStep: some View {
        VStack(spacing: 12) {
            optionRow(icon: "IconFlag", isSystemIcon: false, title: "Muscle Built", isSelected: appState.selectedGoal == "Muscle Built") {
                appState.selectedGoal = "Muscle Built"
            }
            optionRow(icon: "lock.fill", title: "Lose Weight", isSelected: appState.selectedGoal == "Lose Weight") {
                appState.selectedGoal = "Lose Weight"
            }
            optionRow(icon: "bolt.fill", title: "Stay Fit & Healthy", isSelected: appState.selectedGoal == "Stay Fit & Healthy") {
                appState.selectedGoal = "Stay Fit & Healthy"
            }
            optionRow(icon: "sparkle", title: "Get Stronger", isSelected: appState.selectedGoal == "Get Stronger") {
                appState.selectedGoal = "Get Stronger"
            }
        }
    }

    // MARK: Step 3 — contraindications

    private let contradictionOptions = ["Allergic", "Diabetes", "Astma"]

    private var contradictionsStep: some View {
        VStack(spacing: 22) {
            Text("Do you have any\ncontradictions?")
                .multilineTextAlignment(.center)
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(.white)
                .padding(.top, 18)

            FlowChips(items: contradictionOptions, selected: $appState.selectedContradictions)

            Spacer(minLength: 40)

            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 10) {
                    TextField("", text: $appState.contradictionsNote, prompt: Text("Type here…").foregroundStyle(.white.opacity(0.4)))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .glassEffect(.regular, in: Capsule())
                    Button {} label: {
                        Image("IconSend").customIcon(size: 18)
                            .foregroundStyle(.white)
                            .frame(width: 48, height: 48)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.tint(.appAccentPurple).interactive(), in: Circle())
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color.appSurface.opacity(0.5))
        .overlay(RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous).stroke(Color.appDivider, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous))
    }

    // MARK: Step 4 — level

    private var levelStep: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            levelCard(title: "Beginner", subtitle: "This means\nyou've just started")
            levelCard(title: "Intermediate", subtitle: "Have an\nexperience")
            levelCard(title: "Amateur", subtitle: "I workout all\nthe time")
            levelCard(title: "Advanced", subtitle: "I know\neverything")
        }
    }

    private func levelCard(title: String, subtitle: String) -> some View {
        let isSelected = appState.selectedLevel == title
        return Button { appState.selectedLevel = title } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.appTextSecondary)
            }
            .frame(maxWidth: .infinity, minHeight: 193, alignment: .topLeading)
            .padding(16)
            .overlay(
                RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous)
                    .stroke(isSelected ? Color.appAccent : Color.appDivider, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Shared row style (steps 1 & 2)

    private func optionRow(icon: String? = nil, isSystemIcon: Bool = true, title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let icon {
                    Group {
                        if isSystemIcon {
                            Image(systemName: icon).font(.system(size: 15))
                        } else {
                            Image(icon).customIcon(size: 17)
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(width: 20)
                }
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                if isSelected {
                    ZStack {
                        Circle().fill(Color.appAccent)
                        Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                    }
                    .frame(width: 34, height: 34)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, isSelected ? 6 : 18)
            .frame(maxWidth: .infinity, minHeight: 72)
            .overlay(Capsule().stroke(Color.appDivider, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// Simple two-row wrap of pill chips, matching the fixed 2-then-1 layout in
/// the design (three short chip labels never need real flow-layout math).
private struct FlowChips: View {
    let items: [String]
    @Binding var selected: Set<String>

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                ForEach(items.prefix(2), id: \.self) { chip(for: $0) }
            }
            HStack(spacing: 10) {
                ForEach(items.dropFirst(2), id: \.self) { chip(for: $0) }
                Spacer()
            }
        }
    }

    private func chip(for item: String) -> some View {
        let isOn = selected.contains(item)
        return Text(item)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(isOn ? Color.appAccent : Color.white.opacity(0.06))
            .overlay(Capsule().stroke(isOn ? .clear : Color.appDivider, lineWidth: 1))
            .clipShape(Capsule())
            .onTapGesture {
                if isOn { selected.remove(item) } else { selected.insert(item) }
            }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppState())
}
