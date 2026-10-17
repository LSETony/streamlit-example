import ActivityKit
import Foundation

/// Drives the workout Live Activity shown on the Lock Screen and in the
/// Dynamic Island while ActiveWorkoutView has a session running.
///
/// Compiled into BOTH the CoreApp target (which calls
/// Activity.request/update/end — see LiveActivityService.swift) and the
/// CoreWidgets extension target (which renders it — see
/// WorkoutLiveActivity.swift). Both target memberships are set in
/// project.pbxproj; any change here needs to stay source-compatible with
/// both, since ActivityKit requires the exact same attribute type on both
/// sides of the app/extension boundary.
struct WorkoutActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var exerciseName: String
        var exerciseIndex: Int
        var totalExercises: Int
        var currentSet: Int
        var totalSets: Int
        var isPaused: Bool
        /// Next exercise's name, so the expanded island can preview what's
        /// coming — nil on the last exercise.
        var nextExerciseName: String?
        /// Rough calories burned so far (same ~7 kcal/min estimate
        /// recordCompletion uses), refreshed whenever the app calls
        /// update() — not itself ticking live.
        var estimatedCalories: Int
        /// Start date shifted forward by every second already spent
        /// paused — paired with `pausedAt` below, this lets the widget
        /// render a real system-ticking `Text(timerInterval:pauseTime:)`
        /// that shows active elapsed time (pauses excluded) without the
        /// app updating the Live Activity every second.
        var elapsedStartDate: Date
        /// The exact moment the current pause began — nil while playing.
        var pausedAt: Date?
        /// True for the final update sent right as the workout finishes —
        /// WorkoutLiveActivity swaps the whole presentation to a
        /// "complete" look (checkmark, no more live timer) instead of the
        /// in-progress exercise/set view. LiveActivityService.end() is
        /// called a few seconds after this update, not immediately, so
        /// there's actually time to see it on the island.
        var isCompleted: Bool = false
        /// An achievement newly unlocked by finishing this workout (e.g.
        /// "10 Workouts") — nil if this session didn't unlock a new one.
        /// Only meaningful when isCompleted is true.
        var unlockedAchievementTitle: String?
        var unlockedAchievementIcon: String?
    }

    var workoutTitle: String
}
