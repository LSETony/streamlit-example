import Foundation

/// A compact, personal snapshot of this member's own progress — written by
/// the main app whenever streak/workout state changes, read by the
/// Progress & Achievements Home Screen widget. Compiled into BOTH the
/// CoreApp and CoreWidgets targets (see WorkoutActivityAttributes.swift's
/// doc comment for why that's how shared types work here); any change
/// needs to stay source-compatible with both sides.
///
/// Unlike WorkoutOfTheDayWidget (deliberately public, non-personal data
/// fetched straight from Supabase so it needs no App Group), this is
/// genuinely personal — this member's own streak and achievements — so it
/// goes through a shared App Group container instead: the app writes a
/// JSON snapshot to shared UserDefaults and nudges WidgetKit to redraw,
/// the widget just reads the latest snapshot. No network call, no
/// credentials in the widget, and it works the moment the app has synced
/// once, even offline.
struct ProgressSnapshot: Codable {
    var streakDays: Int
    var totalWorkouts: Int
    var unlockedAchievements: Int
    var totalAchievements: Int
    var weeklySets: Int
    var weeklyMinutes: Int
    var weeklyCalories: Int
    var lastWorkoutTitle: String?
    var updatedAt: Date

    static let placeholder = ProgressSnapshot(
        streakDays: 4, totalWorkouts: 12, unlockedAchievements: 2, totalAchievements: 6,
        weeklySets: 38, weeklyMinutes: 128, weeklyCalories: 920,
        lastWorkoutTitle: "Chest and Triceps", updatedAt: Date()
    )
}

enum SharedProgressStore {
    static let appGroupID = "group.com.coreclub.app"
    private static let key = "core.progressSnapshot"

    static func save(_ snapshot: ProgressSnapshot) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }

    static func load() -> ProgressSnapshot? {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return nil }
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(ProgressSnapshot.self, from: data)
    }
}
