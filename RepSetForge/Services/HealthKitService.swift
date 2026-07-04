import Foundation
import HealthKit

/// Bridges completed quests to Apple Health: writes them as workouts (with
/// an estimated active-energy sample, since this app has no wearable sensor
/// data of its own) and reads back heart rate / body mass so future features
/// can use them. Every call is gated behind `isAvailable`, and every
/// HealthKit failure is meant to be caught and ignored by the caller (a
/// denied/unavailable Health integration should never block logging a
/// workout in RepSetForge itself).
enum HealthKitService {
    static let store = HKHealthStore()

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    static let workoutType = HKObjectType.workoutType()
    static let activeEnergyType = HKQuantityType(.activeEnergyBurned)
    static let heartRateType = HKQuantityType(.heartRate)
    static let bodyMassType = HKQuantityType(.bodyMass)

    static let typesToShare: Set<HKSampleType> = [workoutType, activeEnergyType]
    static let typesToRead: Set<HKObjectType> = [workoutType, activeEnergyType, heartRateType, bodyMassType]

    /// Metabolic equivalent for traditional strength training, used only to
    /// *estimate* active energy burned — RepSetForge has no wearable sensor
    /// of its own, so this is an approximation, not a measured figure.
    static let strengthTrainingMET = 5.0
    /// Assumed body weight when Health has no recorded body mass to read —
    /// used only as an estimate input, never shown to the user as fact.
    static let fallbackBodyWeightKilograms = 70.0
    /// Rough per-set duration used to approximate a workout's start time,
    /// since individual sets aren't independently timestamped.
    static let estimatedSecondsPerSet: TimeInterval = 300

    static func requestAuthorization() async throws {
        guard isAvailable else { return }
        try await store.requestAuthorization(toShare: typesToShare, read: typesToRead)
    }

    /// Kilocalories for `durationSeconds` of strength training at
    /// `bodyWeightKilograms`, via the standard MET formula
    /// (kcal = MET × kg × hours). Pure and independent of HealthKit itself
    /// so it's directly testable.
    static func estimatedActiveEnergyKilocalories(durationSeconds: TimeInterval, bodyWeightKilograms: Double) -> Double {
        strengthTrainingMET * bodyWeightKilograms * (durationSeconds / 3600)
    }

    /// The Health workout's start/end range for a completed quest — nil for
    /// a quest that was never completed (nothing to log). The start time is
    /// approximated backward from the completion time using the number of
    /// completed sets, since sets aren't individually timestamped.
    static func workoutDateRange(for quest: Quest, secondsPerSet: TimeInterval = estimatedSecondsPerSet) -> (start: Date, end: Date)? {
        guard let completedDate = quest.completedDate else { return nil }
        let completedSetCount = quest.exercises.reduce(0) { $0 + $1.completedSets.count }
        let estimatedDuration = TimeInterval(max(completedSetCount, 1)) * secondsPerSet
        return (completedDate.addingTimeInterval(-estimatedDuration), completedDate)
    }

    /// Saves a workout to Health spanning `start`...`end`, with an estimated
    /// active-energy sample. Takes a plain date range (computed synchronously
    /// via `workoutDateRange(for:)` on the caller's side) rather than a
    /// `Quest` directly, since SwiftData model objects aren't `Sendable` and
    /// this call crosses into an async context. Returns `false` (rather than
    /// throwing) when Health isn't available, since that's an expected
    /// no-op, not a failure.
    @discardableResult
    static func saveWorkout(start: Date, end: Date) async throws -> Bool {
        guard isAvailable else { return false }

        let bodyWeight = (try? await mostRecentBodyMassKilograms()) ?? fallbackBodyWeightKilograms
        let energy = estimatedActiveEnergyKilocalories(durationSeconds: end.timeIntervalSince(start), bodyWeightKilograms: bodyWeight)

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining

        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())
        try await builder.beginCollection(at: start)

        let energySample = HKQuantitySample(
            type: activeEnergyType,
            quantity: HKQuantity(unit: .kilocalorie(), doubleValue: energy),
            start: start,
            end: end
        )
        try await builder.addSamples([energySample])
        try await builder.endCollection(at: end)
        _ = try await builder.finishWorkout()
        return true
    }

    static func mostRecentBodyMassKilograms() async throws -> Double? {
        try await mostRecentQuantitySample(for: bodyMassType, unit: .gramUnit(with: .kilo))
    }

    static func mostRecentHeartRateBPM() async throws -> Double? {
        try await mostRecentQuantitySample(for: heartRateType, unit: HKUnit.count().unitDivided(by: .minute()))
    }

    private static func mostRecentQuantitySample(for type: HKQuantityType, unit: HKUnit) async throws -> Double? {
        guard isAvailable else { return nil }
        let sortByRecency = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sortByRecency]) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: sample.quantity.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }
}
