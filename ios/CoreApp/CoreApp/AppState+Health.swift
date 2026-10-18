import Foundation
import WidgetKit

/// Backs HealthMetricsView and the HealthMetricsWidget — reads from
/// HealthKitService (see its doc comment for which metrics are real
/// HealthKit reads vs. not implemented at all) and publishes onto
/// AppState's health properties, then mirrors the glanceable subset into
/// the shared App Group snapshot the widget reads.
extension AppState {
    /// Call on launch (if Apple Health sync is already on) and whenever
    /// HealthMetricsView appears — HealthKitService's own calls already
    /// no-op instantly if sync is off or HealthKit is unavailable, so this
    /// is always safe to call.
    func refreshHealthMetrics() async {
        guard appleHealthSyncEnabled, HealthKitService.shared.isAvailable else { return }

        async let heartRate = HealthKitService.shared.latestHeartRate()
        async let steps = HealthKitService.shared.todaySteps()
        async let hydration = HealthKitService.shared.todayHydrationML()
        async let bmiValue = HealthKitService.shared.latestBMI()
        async let sleep = HealthKitService.shared.lastNightSleepMinutes()
        async let bloodPressure = HealthKitService.shared.latestBloodPressure()
        async let glucose = HealthKitService.shared.latestBloodGlucose()

        let (heartRateValue, stepsValue, hydrationValue, bmiResult, sleepValue, bpResult, glucoseValue) = await (
            heartRate, steps, hydration, bmiValue, sleep, bloodPressure, glucose
        )

        heartRateBPM = heartRateValue.map(Int.init)
        todaySteps = stepsValue
        hydrationML = hydrationValue.map(Int.init)
        bmi = bmiResult
        sleepMinutesLastNight = sleepValue
        bloodPressureSystolic = bpResult.map { Int($0.systolic) }
        bloodPressureDiastolic = bpResult.map { Int($0.diastolic) }
        bloodGlucose = glucoseValue.map(Int.init)
        healthMetricsUpdatedAt = Date()

        SharedHealthStore.save(
            HealthSnapshot(
                heartRateBPM: heartRateBPM, steps: todaySteps, hydrationML: hydrationML,
                bmi: bmi, sleepMinutes: sleepMinutesLastNight, updatedAt: Date()
            )
        )
        WidgetCenter.shared.reloadTimelines(ofKind: "HealthMetricsWidget")
    }
}
