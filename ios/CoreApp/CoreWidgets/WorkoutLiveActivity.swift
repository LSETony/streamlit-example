import ActivityKit
import WidgetKit
import SwiftUI

/// The on-screen presentation for the workout Live Activity — Lock Screen
/// banner + all four Dynamic Island presentations (compact, minimal,
/// expanded). Driven entirely by WorkoutActivityAttributes.ContentState,
/// which LiveActivityService.swift (CoreApp target) updates as
/// ActiveWorkoutView steps through sets/exercises.
struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(Color.appAccent)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.currentSet)/\(context.state.totalSets)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text(context.state.exerciseName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text("Exercise \(context.state.exerciseIndex + 1) of \(context.state.totalExercises)")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            } compactLeading: {
                Image(systemName: "flame.fill")
                    .foregroundStyle(Color.appAccent)
            } compactTrailing: {
                Text("\(context.state.currentSet)/\(context.state.totalSets)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            } minimal: {
                Image(systemName: "flame.fill")
                    .foregroundStyle(Color.appAccent)
            }
        }
    }

    private func lockScreenView(context: ActivityViewContext<WorkoutActivityAttributes>) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "flame.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.appAccent)
            VStack(alignment: .leading, spacing: 2) {
                Text(context.attributes.workoutTitle)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(context.state.exerciseName)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(context.state.exerciseIndex + 1)/\(context.state.totalExercises)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                Text("set \(context.state.currentSet)/\(context.state.totalSets)")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(16)
        .activityBackgroundTint(Color.appSurface)
        .activitySystemActionForegroundColor(.white)
    }
}
