import SwiftUI

/// Figma frame 161:253 "iPhone 16 & 17 Pro Max - 13", step 3/4.
struct HealthQuestionsView: View {
    @ObservedObject var answers: OnboardingAnswers
    var onBack: () -> Void
    var onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            OnboardingHeader(
                title: "Tell us about yourself",
                subtitle: "This tailor plans and your experience",
                step: 3,
                totalSteps: 4,
                onBack: onBack
            )

            VStack(alignment: .leading, spacing: 20) {
                Text("Do you have any contradictions?")
                    .font(Theme.Typeface.display(24, weight: .semibold))
                    .foregroundStyle(.white)

                HStack(spacing: 12) {
                    ForEach(Condition.allCases, id: \.self) { condition in
                        conditionChip(condition)
                    }
                }

                Button {
                    answers.hasNoContradictions.toggle()
                    if answers.hasNoContradictions { answers.conditions.removeAll() }
                } label: {
                    HStack {
                        Text("None of the above")
                            .font(Theme.Typeface.display(16, weight: .medium))
                            .foregroundStyle(.white)
                        Spacer()
                        ZStack {
                            Circle().fill(answers.hasNoContradictions ? Theme.orange : Theme.cardFill)
                            if answers.hasNoContradictions {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(width: 40, height: 40)
                    }
                    .padding(.horizontal, 20)
                    .frame(height: 72)
                    .background(Theme.cardFill, in: RoundedRectangle(cornerRadius: Theme.pillRadius, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .background(Color.black.opacity(0.2), in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))

            Spacer()

            PrimaryButton(title: "Continue", action: onContinue)
        }
        .padding(.horizontal, Theme.Metrics.screenPadding)
        .padding(.top, 70)
        .padding(.bottom, 24)
    }

    private func conditionChip(_ condition: Condition) -> some View {
        let isSelected = answers.conditions.contains(condition)
        return Button {
            if isSelected {
                answers.conditions.remove(condition)
            } else {
                answers.conditions.insert(condition)
                answers.hasNoContradictions = false
            }
        } label: {
            Text(condition.rawValue)
                .font(Theme.Typeface.display(16, weight: .medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 59)
                .background(
                    isSelected ? Theme.orange.opacity(0.35) : Theme.cardFill,
                    in: RoundedRectangle(cornerRadius: Theme.pillRadius, style: .continuous)
                )
        }
        .buttonStyle(.plain)
    }
}
