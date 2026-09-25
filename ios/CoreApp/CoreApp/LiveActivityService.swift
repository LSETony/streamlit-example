import Foundation
import ActivityKit

/// Starts/updates/ends the workout Live Activity (Lock Screen + Dynamic
/// Island) — called from ActiveWorkoutView as a session progresses. The
/// actual on-screen presentation lives in the CoreWidgets extension
/// target's WorkoutLiveActivity.swift; this side only feeds it data
/// through the shared WorkoutActivityAttributes type.
@MainActor
enum LiveActivityService {
    private static var current: Activity<WorkoutActivityAttributes>?

    /// False on a device/OS where Live Activities aren't available, or
    /// when the member has turned them off in Settings — every call below
    /// already checks this, so callers can invoke them unconditionally.
    static var isSupported: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    static func start(workoutTitle: String, state: WorkoutActivityAttributes.ContentState) {
        guard isSupported else { return }
        end() // never more than one workout activity at a time
        let attributes = WorkoutActivityAttributes(workoutTitle: workoutTitle)
        do {
            current = try Activity.request(attributes: attributes, content: .init(state: state, staleDate: nil))
        } catch {
            print("LiveActivityService.start failed: \(error)")
        }
    }

    static func update(_ state: WorkoutActivityAttributes.ContentState) {
        guard let current else { return }
        Task { await current.update(.init(state: state, staleDate: nil)) }
    }

    static func end() {
        guard let activity = current else { return }
        current = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }
}
