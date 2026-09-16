import SwiftUI

/// Figma frame 51:704 "iPhone 16 & 17 Pro Max - 5", step 4/4.
struct LevelSelectionView: View {
    @ObservedObject var answers: OnboardingAnswers
    var onBack: () -> Void
    var onContinue: () -> Void

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            OnboardingHeader(
                title: "Choose your level",
                subtitle: "This tailor plans and your experience",
                step: 4,
                totalSteps: 4,
                onBack: onBack
            )

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(FitnessLevel.allCases, id: \.self) { level in
                    LevelTile(
                        title: level.rawValue,
                        subtitle: level.subtitle,
                        isSelected: answers.level == level
                    ) {
                        answers.level = level
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
