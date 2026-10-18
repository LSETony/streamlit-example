import Foundation

/// A compact snapshot of this member's latest Apple Health readings —
/// written by the main app whenever refreshHealthMetrics() runs (see
/// AppState+Health.swift), read by HealthMetricsWidget. Same App Group
/// pattern as SharedProgressStore — see its doc comment for why this goes
/// through shared UserDefaults instead of the widget querying HealthKit
/// itself (no HealthKit entitlement/usage-description duplication needed
/// in the widget extension, works offline, always reflects whatever the
/// app last synced). Compiled into BOTH the CoreApp and CoreWidgets
/// targets; any change needs to stay source-compatible with both.
struct HealthSnapshot: Codable {
    var heartRateBPM: Int?
    var steps: Int?
    var hydrationML: Int?
    var bmi: Double?
    var sleepMinutes: Int?
    var updatedAt: Date

    static let placeholder = HealthSnapshot(
        heartRateBPM: 84, steps: 6240, hydrationML: 1250, bmi: 22.4, sleepMinutes: 405, updatedAt: Date()
    )
}

enum SharedHealthStore {
    private static let key = "core.healthSnapshot"

    static func save(_ snapshot: HealthSnapshot) {
        guard let defaults = UserDefaults(suiteName: SharedProgressStore.appGroupID) else { return }
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }

    static func load() -> HealthSnapshot? {
        guard let defaults = UserDefaults(suiteName: SharedProgressStore.appGroupID) else { return nil }
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(HealthSnapshot.self, from: data)
    }
}
