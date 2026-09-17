import SwiftUI

/// Opened when a workout card in the library is tapped — shows the plan's
/// full exercise breakdown and lets the user start a live session that
/// steps through each exercise/set.
struct WorkoutDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let card: WorkoutCard
    @State private var isSessionActive = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Image(card.imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 220)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: AppMetrics.cardCorner, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(card.title)
                        .font(.brand(26))
                        .foregroundStyle(.white)
                    HStack(spacing: 8) {
                        pill(card.level)
                        pill(card.duration)
                        pill("\(card.exercises.count) exercises")
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    EyebrowLabel(text: "Exercises")
                    VStack(spacing: 10) {
                        ForEach(Array(card.exercises.enumerated()), id: \.element.id) { index, exercise in
                            exerciseRow(index: index, exercise: exercise)
                        }
                    }
                }

                PrimaryButton(title: "Start Workout") {
                    isSessionActive = true
                }
            }
            .screenPadding()
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }.foregroundStyle(Color.appAccent)
            }
        }
        .navigationDestination(isPresented: $isSessionActive) {
            ActiveWorkoutView(card: card)
        }
    }

    private func pill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color.appAccent)
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .background(Color.appAccentDim)
            .clipShape(Capsule())
    }

    private func exerciseRow(index: Int, exercise: Exercise) -> some View {
        HStack(spacing: 12) {
            Text("\(index + 1)")
                .font(.digitalTimer(16))
                .foregroundStyle(Color.appAccent)
                .frame(width: 28, height: 28)
                .background(Color.appAccentDim)
                .clipShape(Circle())

            Image(systemName: exercise.icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(.white.opacity(0.08))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Text("\(exercise.sets) sets · \(exercise.reps)")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.appTextSecondary)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppMetrics.smallCorner, style: .continuous))
    }
}

/// A live session that steps through the plan's exercises one set at a
/// time, then shows a finish summary with the total elapsed time.
struct ActiveWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    let card: WorkoutCard
    @State private var exerciseIndex = 0
    @State private var currentSet = 1
    private let startedAt = Date()

    private var isFinished: Bool { exerciseIndex >= card.exercises.count }
    private var currentExercise: Exercise? {
        isFinished ? nil : card.exercises[exerciseIndex]
    }

    var body: some View {
        VStack(spacing: 24) {
            if isFinished {
                finishedContent
            } else if let exercise = currentExercise {
                inProgressContent(exercise: exercise)
            }
        }
        .screenPadding()
        .padding(.top, 12)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isFinished)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("End") { dismiss() }.foregroundStyle(Color.appTextSecondary)
            }
        }
    }

    @ViewBuilder
    private func inProgressContent(exercise: Exercise) -> some View {
        EyebrowLabel(text: "Exercise \(exerciseIndex + 1) of \(card.exercises.count)")
        ProgressBarView(value: Double(exerciseIndex) / Double(max(card.exercises.count, 1)))

        Spacer(minLength: 0)

        VStack(spacing: 16) {
            Image(systemName: exercise.icon)
                .font(.system(size: 48, weight: .medium))
                .foregroundStyle(Color.appAccent)
                .frame(width: 120, height: 120)
                .background(Color.appAccentDim)
                .clipShape(Circle())

            Text(exercise.name)
                .font(.brand(26))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(exercise.reps)
                .font(.digitalTimer(40))
                .foregroundStyle(.white)

            Text("Set \(currentSet) of \(exercise.sets)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.appTextSecondary)
        }

        Spacer(minLength: 0)

        PrimaryButton(title: currentSet < exercise.sets ? "Complete Set" : "Next Exercise") {
            advance(exercise: exercise)
        }
    }

    private var finishedContent: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 0)
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.appSuccess)
            Text("Workout complete!")
                .font(.brand(26))
                .foregroundStyle(.white)
            TimelineView(.periodic(from: startedAt, by: 1)) { context in
                Text(elapsedString(from: startedAt, to: context.date))
                    .font(.digitalTimer(36))
                    .foregroundStyle(Color.appAccent)
            }
            Text("\(card.exercises.count) exercises · \(card.title)")
                .font(.system(size: 13))
                .foregroundStyle(Color.appTextSecondary)
            Spacer(minLength: 0)
            PrimaryButton(title: "Done") { dismiss() }
        }
    }

    private func advance(exercise: Exercise) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            if currentSet < exercise.sets {
                currentSet += 1
            } else {
                exerciseIndex += 1
                currentSet = 1
            }
        }
    }

    private func elapsedString(from start: Date, to now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(start)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

#Preview {
    NavigationStack {
        WorkoutDetailView(card: AppState().beginnerPlanCards[0])
    }
}
