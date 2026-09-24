import Foundation
import HealthKit

/// Reads/writes Apple Health — wired to the "Apple Health" toggle on
/// Profile and to ActiveWorkoutView's finish screen (which writes a real
/// HKWorkout once a session completes). Info.plist already carries the
/// NSHealthShareUsageDescription/NSHealthUpdateUsageDescription strings
/// this needs; CoreApp.entitlements adds the HealthKit capability.
///
/// Same caveat as Sign in with Apple (see AuthService.isAppleSignInConfigured's
/// comment): some capabilities can't be provisioned on a free/personal
/// Apple Developer team and need the paid Program. If Xcode reports
/// "Personal development teams do not support the HealthKit capability"
/// when building, remove the entitlement (like Sign in with Apple was
/// reverted) — `isAvailable` below already guards every call so nothing
/// else needs to change if that happens.
@MainActor
final class HealthKitService {
    static let shared = HealthKitService()
    private let store = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private var workoutType: HKObjectType { HKObjectType.workoutType() }
    private var activeEnergyType: HKQuantityType { HKQuantityType(.activeEnergyBurned) }
    private var stepCountType: HKQuantityType { HKQuantityType(.stepCount) }

    /// Returns true once the member has granted (or already grants) both
    /// read and write access. Profile's toggle calls this and reverts
    /// itself if it comes back false.
    @discardableResult
    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        let toShare: Set<HKSampleType> = [HKObjectType.workoutType()]
        let toRead: Set<HKObjectType> = [workoutType, activeEnergyType, stepCountType]
        do {
            try await store.requestAuthorization(toShare: toShare, read: toRead)
            return true
        } catch {
            print("HealthKit authorization failed: \(error)")
            return false
        }
    }

    /// Writes a completed workout back to Health — called right after
    /// ActiveWorkoutView finishes a session, when Apple Health sync is on.
    func saveWorkout(activityType: HKWorkoutActivityType, start: Date, end: Date, calories: Double) {
        guard isAvailable else { return }
        let energyUnit = HKUnit.kilocalorie()
        let energySample = HKQuantitySample(
            type: activeEnergyType, quantity: HKQuantity(unit: energyUnit, doubleValue: calories),
            start: start, end: end
        )
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = activityType
        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())
        builder.beginCollection(withStart: start) { [weak self] _, _ in
            builder.add([energySample]) { _, _ in
                builder.endCollection(withEnd: end) { _, _ in
                    builder.finishWorkout { _, error in
                        if let error { print("HealthKit saveWorkout failed: \(error)") }
                    }
                }
            }
            _ = self
        }
    }

    /// Today's step count, for a small stat somewhere on Profile/Progress —
    /// returns nil if unavailable or not authorized.
    func todaySteps() async -> Int? {
        guard isAvailable else { return nil }
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: stepCountType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, statistics, _ in
                let steps = statistics?.sumQuantity()?.doubleValue(for: .count())
                continuation.resume(returning: steps.map(Int.init))
            }
            store.execute(query)
        }
    }
}
