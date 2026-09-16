import SwiftUI

/// Figma frame 163:373 "iPhone 16 & 17 Pro Max - 14", step 1/4.
struct GenderSelectionView: View {
    @ObservedObject var answers: OnboardingAnswers
    var onBack: (() -> Void)?
    var onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            OnboardingHeader(
                title: "Tell us about yourself",
                subtitle: "This tailor plans and your experience",
                step: 1,
                totalSteps: 4,
                onBack: onBack
            )

            VStack(spacing: 16) {
                ForEach(Gender.allCases, id: \.self) { gender in
                    SelectableBar(title: gender.rawValue, isSelected: answers.gender == gender) {
                        answers.gender = gender
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
