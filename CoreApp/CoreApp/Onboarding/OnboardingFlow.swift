import SwiftUI

/// Coordinates the 4-step onboarding questionnaire. Step order follows the "x/4" progress
/// labels found in the Figma frames: Gender (1/4) → Goal (2/4) → Health (3/4) → Level (4/4).
struct OnboardingFlow: View {
    @StateObject private var answers = OnboardingAnswers()
    @State private var step = 1
    var onFinished: () -> Void

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            Group {
                switch step {
                case 1:
                    GenderSelectionView(answers: answers, onBack: nil) { step = 2 }
                case 2:
                    GoalSelectionView(answers: answers) { step = 1 } onContinue: { step = 3 }
                case 3:
                    HealthQuestionsView(answers: answers) { step = 2 } onContinue: { step = 4 }
                default:
                    LevelSelectionView(answers: answers) { step = 3 } onContinue: { onFinished() }
                }
            }
            .transition(.opacity)
        }
        .animation(.easeInOut(duration: 0.2), value: step)
    }
}
