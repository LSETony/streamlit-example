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
                .font(.brand(32))
                .foregroundStyle(.white)
            Text("This tailor plans and your experience")
                .font(.brand(13))
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
                .font(.brand(12))
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

    private var contradictionsStep: some View {
        VStack(spacing: 24) {
            Text("Do you have any\ncontradictions?")
                .multilineTextAlignment(.center)
                .font(.brand(22))
                .foregroundStyle(.white)
                .padding(.top, 18)

            FlowChips(items: appState.contradictionOptions, selected: $appState.selectedContradictions)

            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 10) {
                    TextField("", text: $appState.contradictionsNote, prompt: Text("Type here…").foregroundStyle(.white.opacity(0.4)))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .glassEffect(.regular, in: Capsule())
                        .onSubmit(submitContradictionNote)
                    Button(action: submitContradictionNote) {
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

    /// Turns whatever the member typed into its own chip (added to the
    /// options list so it's there automatically next time) and selects it.
    /// The free text itself is kept on `appState` for later processing.
    private func submitContradictionNote() {
        let note = appState.contradictionsNote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !note.isEmpty else { return }
        if !appState.contradictionOptions.contains(note) {
            appState.contradictionOptions.append(note)
        }
        appState.selectedContradictions.insert(note)
        appState.contradictionsNote = ""
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
            ZStack(alignment: .topLeading) {
                if isSelected, title == "Beginner" {
                    GeometryReader { geo in
                        ZStack {
                            Image("WorkoutBeginnerFemale")
                                .resizable()
                                .scaledToFill()
                                .frame(width: geo.size.width, height: geo.size.height)
                                .clipped()
                            LinearGradient(colors: [.black.opacity(0.1), .black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
                        }
                    }
                } else if isSelected {
                    Color.appAccentPurple
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.brand(16))
                        .foregroundStyle(.white)
                    Spacer()
                    Text(subtitle)
                        .font(.brand(12))
                        .foregroundStyle(isSelected ? .white.opacity(0.9) : Color.appTextSecondary)
                }
                .padding(16)
            }
            .frame(maxWidth: .infinity, minHeight: 193, alignment: .topLeading)
            .clipShape(RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous)
                    .stroke(isSelected ? Color.clear : Color.appDivider, lineWidth: 1)
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
                    .font(.brand(16))
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

/// Wraps pill chips onto as many rows as needed — the option list grows as
/// the member types custom contraindications, so a fixed 2-then-1 layout
/// no longer fits every case.
private struct FlowChips: View {
    let items: [String]
    @Binding var selected: Set<String>

    var body: some View {
        FlowLayout(spacing: 10) {
            ForEach(items, id: \.self) { chip(for: $0) }
        }
    }

    private func chip(for item: String) -> some View {
        let isOn = selected.contains(item)
        return Text(item)
            .font(.brand(14))
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

/// A minimal left-to-right, top-to-bottom wrapping layout for same-height
/// chip rows.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 10

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalWidth: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth > 0, rowWidth + spacing + size.width > maxWidth {
                totalHeight += rowHeight + spacing
                totalWidth = max(totalWidth, rowWidth)
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += (rowWidth > 0 ? spacing : 0) + size.width
            rowHeight = max(rowHeight, size.height)
        }
        totalWidth = max(totalWidth, rowWidth)
        totalHeight += rowHeight
        return CGSize(width: totalWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppState())
}
