import SwiftUI

/// Figma frame 51:574 "iPhone 16 & 17 Pro Max - 4", step 2/4.
struct GoalSelectionView: View {
    @ObservedObject var answers: OnboardingAnswers
    var onBack: () -> Void
    var onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            OnboardingHeader(
                title: "What's your goal?",
                subtitle: "This tailor plans and your experience",
                step: 2,
                totalSteps: 4,
                onBack: onBack
            )

            VStack(spacing: 12) {
                ForEach(Goal.allCases, id: \.self) { goal in
                    OptionRow(icon: goal.icon, title: goal.rawValue, isSelected: answers.goal == goal) {
                        answers.goal = goal
                    }
                }
            }

            Spacer()

            PrimaryButton(title: "Continue", action: onContinue)
        }
        .padding(.horizontal, Theme.Metrics.screenPadding)
        .padding(.top, 70)
        .padding(.bottom, 24)
    }
}
