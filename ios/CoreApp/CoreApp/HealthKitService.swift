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
    private var heartRateType: HKQuantityType { HKQuantityType(.heartRate) }
    private var dietaryWaterType: HKQuantityType { HKQuantityType(.dietaryWater) }
    private var bodyMassIndexType: HKQuantityType { HKQuantityType(.bodyMassIndex) }
    private var bloodPressureSystolicType: HKQuantityType { HKQuantityType(.bloodPressureSystolic) }
    private var bloodPressureDiastolicType: HKQuantityType { HKQuantityType(.bloodPressureDiastolic) }
    private var bloodGlucoseType: HKQuantityType { HKQuantityType(.bloodGlucose) }
    private var sleepType: HKCategoryType { HKCategoryType(.sleepAnalysis) }

    /// Returns true once the member has granted (or already grants) both
    /// read and write access. Profile's toggle calls this and reverts
    /// itself if it comes back false.
    @discardableResult
    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        let toShare: Set<HKSampleType> = [HKObjectType.workoutType()]
        let toRead: Set<HKObjectType> = [
            workoutType, activeEnergyType, stepCountType, heartRateType, dietaryWaterType,
            bodyMassIndexType, bloodPressureSystolicType, bloodPressureDiastolicType, bloodGlucoseType, sleepType,
        ]
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

    /// Most recent sample of any quantity type, in `unit` — shared by the
    /// single-value reads below (heart rate, BMI, blood pressure, blood
    /// glucose). Returns nil if unavailable, not authorized, or there's
    /// simply no data of that type yet — several of these (blood pressure,
    /// blood glucose) are normal to come back empty for most members, who
    /// have no reason to be logging either.
    private func latestQuantitySample(_ type: HKQuantityType, unit: HKUnit) async -> Double? {
        guard isAvailable else { return nil }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    /// Most recent heart rate reading, in beats per minute.
    func latestHeartRate() async -> Double? {
        await latestQuantitySample(heartRateType, unit: HKUnit.count().unitDivided(by: .minute()))
    }

    /// Today's logged water intake, in milliliters.
    func todayHydrationML() async -> Double? {
        guard isAvailable else { return nil }
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: dietaryWaterType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, statistics, _ in
                let liters = statistics?.sumQuantity()?.doubleValue(for: .liter())
                continuation.resume(returning: liters.map { $0 * 1000 })
            }
            store.execute(query)
        }
    }

    /// Most recent BMI sample (Health computes/stores this from logged
    /// height + weight — this app doesn't compute it itself).
    func latestBMI() async -> Double? {
        await latestQuantitySample(bodyMassIndexType, unit: .count())
    }

    /// Most recent blood pressure reading — nil unless the member (or a
    /// connected BP cuff) has actually logged one.
    func latestBloodPressure() async -> (systolic: Double, diastolic: Double)? {
        async let systolic = latestQuantitySample(bloodPressureSystolicType, unit: .millimeterOfMercury())
        async let diastolic = latestQuantitySample(bloodPressureDiastolicType, unit: .millimeterOfMercury())
        guard let sys = await systolic, let dia = await diastolic else { return nil }
        return (sys, dia)
    }

    /// Most recent blood glucose reading, in mg/dL — nil unless the member
    /// (or a connected CGM) has actually logged one.
    func latestBloodGlucose() async -> Double? {
        let unit = HKUnit.gramUnit(with: .milli).unitDivided(by: .literUnit(with: .deci))
        return await latestQuantitySample(bloodGlucoseType, unit: unit)
    }

    /// Total time asleep (not just in bed) from the most recent sleep
    /// session HealthKit has — whatever the device's Sleep tracking or a
    /// connected sleep app last recorded, usually last night's.
    func lastNightSleepMinutes() async -> Int? {
        guard isAvailable else { return nil }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let asleepValues: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue,
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
        ]
        return await withCheckedContinuation { continuation in
            // Look back 24h for the most recent sleep sample, then pull
            // every sample sharing that same source/night to sum total
            // asleep time, rather than just the single latest fragment.
            let predicate = HKQuery.predicateForSamples(withStart: Date().addingTimeInterval(-24 * 3600), end: Date(), options: .strictEndDate)
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
                let categorySamples = (samples as? [HKCategorySample]) ?? []
                let totalSeconds = categorySamples
                    .filter { asleepValues.contains($0.value) }
                    .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                continuation.resume(returning: totalSeconds > 0 ? Int(totalSeconds / 60) : nil)
            }
            store.execute(query)
        }
    }
}
