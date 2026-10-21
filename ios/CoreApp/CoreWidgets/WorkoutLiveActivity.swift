import ActivityKit
import WidgetKit
import SwiftUI

/// The on-screen presentation for the workout Live Activity — Lock Screen
/// banner + all four Dynamic Island presentations (compact, minimal,
/// expanded, including the bottom region). Driven entirely by
/// WorkoutActivityAttributes.ContentState, which LiveActivityService.swift
/// (CoreApp target) updates as ActiveWorkoutView steps through
/// sets/exercises — and, once more, as the session's very last update
/// (see WorkoutDetailView.recordCompletion()), with `isCompleted` set and
/// any newly-unlocked achievement attached. Every region below branches on
/// `isCompleted` to swap the whole presentation to a result/celebration
/// look for the few seconds LiveActivityService.endWithFinalUpdate() keeps
/// it on screen before dismissing it, instead of ending the activity with
/// no completion moment at all.
///
/// The elapsed-time Text views use the system's native
/// `Text(timerInterval:pauseTime:)` — iOS ticks these every second on its
/// own, so the island shows a live running clock without the app calling
/// update() every second (which Apple explicitly discourages for Live
/// Activities). `elapsedStartDate`/`pausedAt` already account for
/// accumulated pause time — see WorkoutActivityAttributes' doc comment.
struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    leadingIcon(context.state)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.appSuccess)
                    } else {
                        elapsedTimerText(context.state)
                            .font(.digitalTimer(18))
                            .foregroundStyle(.white)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    if context.state.isCompleted {
                        VStack(spacing: 2) {
                            Text(context.state.unlockedAchievementTitle != nil ? "Achievement Unlocked!" : "Workout Complete!")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            if let title = context.state.unlockedAchievementTitle {
                                Text(title)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Color.appAccentPurple)
                                    .lineLimit(1)
                            }
                        }
                    } else {
                        VStack(spacing: 2) {
                            Text(context.state.isPaused ? "Paused" : context.state.exerciseName)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(context.state.isPaused ? Color.appTextSecondary : .white)
                                .lineLimit(1)
                            Text("Exercise \(context.state.exerciseIndex + 1) of \(context.state.totalExercises)")
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if context.state.isCompleted {
                        completedBottom(context.state)
                    } else {
                        expandedBottom(context.state)
                    }
                }
            } compactLeading: {
                leadingIcon(context.state)
            } compactTrailing: {
                if context.state.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.appSuccess)
                } else {
                    elapsedTimerText(context.state)
                        .font(.system(size: 13, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .frame(width: 44, alignment: .trailing)
                }
            } minimal: {
                leadingIcon(context.state)
            }
        }
    }

    private func leadingIcon(_ state: WorkoutActivityAttributes.ContentState) -> some View {
        Group {
            if state.isCompleted {
                Image(systemName: state.unlockedAchievementTitle != nil ? (state.unlockedAchievementIcon ?? "trophy.fill") : "checkmark.circle.fill")
                    .foregroundStyle(state.unlockedAchievementTitle != nil ? Color.appAccentPurple : Color.appSuccess)
                    .symbolEffect(.bounce, value: state.isCompleted)
            } else {
                Image(systemName: state.isPaused ? "pause.fill" : "flame.fill")
                    .foregroundStyle(state.isPaused ? Color.appTextSecondary : Color.appAccent)
            }
        }
    }

    /// The live-ticking active-elapsed-time text, shared by every
    /// presentation — see this file's top doc comment for how
    /// elapsedStartDate/pausedAt make this both native-ticking and
    /// pause-correct.
    private func elapsedTimerText(_ state: WorkoutActivityAttributes.ContentState) -> Text {
        Text(
            timerInterval: state.elapsedStartDate...Date.distantFuture,
            pauseTime: state.pausedAt,
            countsDown: false,
            showsHours: false
        )
    }

    private func expandedBottom(_ state: WorkoutActivityAttributes.ContentState) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.15))
                    Capsule()
                        .fill(LinearGradient(colors: [Color.appAccentPurple, Color.appAccent], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(4, geo.size.width * Double(state.exerciseIndex) / Double(max(state.totalExercises, 1))))
                }
            }
            .frame(height: 4)

            HStack {
                Text("Set \(state.currentSet)/\(state.totalSets)")
                if let next = state.nextExerciseName {
                    Text("· Next: \(next)")
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Text("\(state.estimatedCalories) kcal")
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white.opacity(0.75))
        }
    }

    /// The expanded island's bottom region once the workout is done —
    /// calorie total plus, if this session unlocked one, the achievement's
    /// own detail line instead of the in-progress exercise bar.
    private func completedBottom(_ state: WorkoutActivityAttributes.ContentState) -> some View {
        HStack(spacing: 6) {
            if state.unlockedAchievementTitle != nil {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.appAccentPurple)
                Text("New achievement earned")
            } else {
                Text("Nice work — see you next session")
            }
            Spacer(minLength: 4)
            Text("\(state.estimatedCalories) kcal")
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.white.opacity(0.8))
    }

    private func lockScreenView(context: ActivityViewContext<WorkoutActivityAttributes>) -> some View {
        HStack(spacing: 14) {
            leadingIcon(context.state)
                .font(.system(size: 22, weight: .bold))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(context.attributes.workoutTitle)
                        .font(.brand(15))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if context.state.isPaused && !context.state.isCompleted {
                        Text("PAUSED")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(0.4)
                            .foregroundStyle(.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.appTextSecondary)
                            .clipShape(Capsule())
                    }
                }
                if context.state.isCompleted {
                    Text(context.state.unlockedAchievementTitle ?? "Workout complete")
                        .font(.system(size: 12, weight: context.state.unlockedAchievementTitle != nil ? .semibold : .regular))
                        .foregroundStyle(context.state.unlockedAchievementTitle != nil ? Color.appAccentPurple : .white.opacity(0.7))
                        .lineLimit(1)
                } else {
                    Text(context.state.exerciseName)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                    if let next = context.state.nextExerciseName {
                        Text("Next: \(next)")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.5))
                            .lineLimit(1)
                    }
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                if context.state.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.appSuccess)
                } else {
                    elapsedTimerText(context.state)
                        .font(.digitalTimer(20))
                        .foregroundStyle(.white)
                }
                Text(context.state.isCompleted ? "\(context.state.estimatedCalories) kcal" : "set \(context.state.currentSet)/\(context.state.totalSets) · \(context.state.estimatedCalories) kcal")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(16)
        .activityBackgroundTint(Color.appSurface)
        .activitySystemActionForegroundColor(.white)
    }
}
