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
    }

    var workoutTitle: String
}
