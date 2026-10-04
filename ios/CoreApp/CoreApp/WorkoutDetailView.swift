import SwiftUI
import HealthKit

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
                ZStack {
                    WorkoutCoverImage(card: card)
                    if let videoURL = card.videoURL {
                        WorkoutHeroVideo(url: videoURL)
                    }
                }
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
    @EnvironmentObject var appState: AppState
    let card: WorkoutCard
    @State private var exerciseIndex = 0
    @State private var currentSet = 1
    @State private var hasRecordedCompletion = false
    @State private var isPaused = false
    /// When the current pause began — nil while not paused. Time spent in
    /// an open pause isn't counted until it's added to
    /// accumulatedPausedDuration on resume (or read live via activeElapsed
    /// while still paused).
    @State private var pauseStartedAt: Date?
    /// Total seconds spent paused so far, across every pause/resume this
    /// session — subtracted from wall-clock time everywhere "how long has
    /// this workout taken" matters (the live timer, the finish screen, and
    /// the logged workoutHistory entry), so pausing doesn't inflate the
    /// real time worked out.
    @State private var accumulatedPausedDuration: TimeInterval = 0
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
                Button("End") {
                    LiveActivityService.end()
                    dismiss()
                }.foregroundStyle(Color.appTextSecondary)
            }
        }
        .onAppear {
            LiveActivityService.start(workoutTitle: card.title, state: currentActivityState)
        }
    }

    private var currentActivityState: WorkoutActivityAttributes.ContentState {
        WorkoutActivityAttributes.ContentState(
            exerciseName: currentExercise?.name ?? "Finished",
            exerciseIndex: exerciseIndex,
            totalExercises: card.exercises.count,
            currentSet: currentSet,
            totalSets: currentExercise?.sets ?? 0,
            isPaused: isPaused
        )
    }

    /// Real elapsed working time as of `referenceDate` — wall-clock time
    /// since start, minus every second spent paused (including the
    /// currently open pause, if any). While paused this naturally stays
    /// constant as referenceDate advances, which is what freezes the
    /// on-screen timer without any special-casing in the TimelineViews
    /// that call this.
    private func activeElapsed(at referenceDate: Date) -> TimeInterval {
        let openPause = isPaused ? referenceDate.timeIntervalSince(pauseStartedAt ?? referenceDate) : 0
        return max(0, referenceDate.timeIntervalSince(startedAt) - accumulatedPausedDuration - openPause)
    }

    private func togglePause() {
        if isPaused {
            if let pauseStartedAt {
                accumulatedPausedDuration += Date().timeIntervalSince(pauseStartedAt)
            }
            pauseStartedAt = nil
            isPaused = false
        } else {
            pauseStartedAt = Date()
            isPaused = true
        }
        LiveActivityService.update(currentActivityState)
    }

    @ViewBuilder
    private func inProgressContent(exercise: Exercise) -> some View {
        HStack {
            EyebrowLabel(text: "Exercise \(exerciseIndex + 1) of \(card.exercises.count)")
            Spacer()
            TimelineView(.periodic(from: startedAt, by: 1)) { context in
                HStack(spacing: 6) {
                    if isPaused {
                        Text("PAUSED")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(0.6)
                            .foregroundStyle(Color.appTextSecondary)
                    }
                    Text(elapsedString(activeElapsed(at: context.date)))
                        .font(.digitalTimer(18))
                        .foregroundStyle(isPaused ? Color.appTextSecondary : Color.appAccent)
                }
            }
        }
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

        HStack(spacing: 12) {
            Button {
                togglePause()
            } label: {
                Image(systemName: isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
            }
            .buttonStyle(.plain)
            .glassCircleButton()

            PrimaryButton(
                title: isPaused ? "Paused — resume to continue" : (currentSet < exercise.sets ? "Complete Set" : "Next Exercise"),
                isEnabled: !isPaused
            ) {
                advance(exercise: exercise)
            }
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
                Text(elapsedString(activeElapsed(at: context.date)))
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
        if isFinished, !hasRecordedCompletion {
            hasRecordedCompletion = true
            recordCompletion()
        } else {
            LiveActivityService.update(currentActivityState)
        }
    }

    /// Logs the session (history entry, streak, Apple Health if synced,
    /// and a Dynamic Island confirmation) the moment the last set finishes.
    private func recordCompletion() {
        let endedAt = Date()
        let totalSets = card.exercises.reduce(0) { $0 + $1.sets }
        let minutes = max(1, Int(activeElapsed(at: endedAt) / 60))
        let calories = Int(Double(minutes) * 7) // rough strength-training estimate, ~7 kcal/min
        appState.workoutHistory.insert(
            WorkoutHistoryEntry(date: "Today", title: card.title, sets: totalSets, minutes: minutes, calories: calories, completedAt: endedAt),
            at: 0
        )
        if appState.appleHealthSyncEnabled {
            HealthKitService.shared.saveWorkout(activityType: .traditionalStrengthTraining, start: startedAt, end: endedAt, calories: Double(calories))
        }
        LiveActivityService.end()
        Task {
            await appState.recordActivity()
            await MainActor.run {
                appState.notificationCenter.trigger(
                    icon: "flame.fill", title: "Workout complete!",
                    subtitle: "\(appState.streakDays)-day streak", accent: .appAccent
                )
            }
        }
    }

    private func elapsedString(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

#Preview {
    NavigationStack {
        WorkoutDetailView(card: WorkoutCard(
            imageName: "WorkoutBeginnerFemale", title: "Beginner Female Aesthetics", level: "Beginner", duration: "7 day", category: "Strength",
            exercises: [Exercise(name: "Bodyweight Squats", icon: "figure.strengthtraining.functional", sets: 3, reps: "15")]
        ))
    }
}
