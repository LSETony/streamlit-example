import ActivityKit
import WidgetKit
import SwiftUI

/// The on-screen presentation for the workout Live Activity — Lock Screen
/// banner + all four Dynamic Island presentations (compact, minimal,
/// expanded, now including the previously-unused bottom region). Driven
/// entirely by WorkoutActivityAttributes.ContentState, which
/// LiveActivityService.swift (CoreApp target) updates as ActiveWorkoutView
/// steps through sets/exercises.
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
                    Image(systemName: context.state.isPaused ? "pause.fill" : "flame.fill")
                        .foregroundStyle(context.state.isPaused ? Color.appTextSecondary : Color.appAccent)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    elapsedTimerText(context.state)
                        .font(.digitalTimer(18))
                        .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.center) {
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
                DynamicIslandExpandedRegion(.bottom) {
                    expandedBottom(context.state)
                }
            } compactLeading: {
                Image(systemName: context.state.isPaused ? "pause.fill" : "flame.fill")
                    .foregroundStyle(context.state.isPaused ? Color.appTextSecondary : Color.appAccent)
            } compactTrailing: {
                elapsedTimerText(context.state)
                    .font(.system(size: 13, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .frame(width: 44, alignment: .trailing)
            } minimal: {
                Image(systemName: context.state.isPaused ? "pause.fill" : "flame.fill")
                    .foregroundStyle(context.state.isPaused ? Color.appTextSecondary : Color.appAccent)
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

    private func lockScreenView(context: ActivityViewContext<WorkoutActivityAttributes>) -> some View {
        HStack(spacing: 14) {
            Image(systemName: context.state.isPaused ? "pause.fill" : "flame.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(context.state.isPaused ? Color.appTextSecondary : Color.appAccent)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(context.attributes.workoutTitle)
                        .font(.brand(15))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if context.state.isPaused {
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
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                elapsedTimerText(context.state)
                    .font(.digitalTimer(20))
                    .foregroundStyle(.white)
                Text("set \(context.state.currentSet)/\(context.state.totalSets) · \(context.state.estimatedCalories) kcal")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(16)
        .activityBackgroundTint(Color.appSurface)
        .activitySystemActionForegroundColor(.white)
    }
}
