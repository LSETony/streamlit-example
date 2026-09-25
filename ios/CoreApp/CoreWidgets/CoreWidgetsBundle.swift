import WidgetKit
import SwiftUI

/// Entry point for the CoreWidgets extension — hosts both the Home Screen
/// widget and the workout Live Activity in one extension target (a single
/// WidgetKit extension can bundle several Widget/ActivityConfiguration
/// types; Apple doesn't require a separate target per widget).
@main
struct CoreWidgetsBundle: WidgetBundle {
    var body: some Widget {
        WorkoutOfTheDayWidget()
        WorkoutLiveActivity()
    }
}
