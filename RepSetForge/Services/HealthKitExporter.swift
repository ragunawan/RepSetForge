import Foundation
import HealthKit

/// §4b Apple Health export. Every write goes through the healthKitUUID
/// guard: first save stores the HKWorkout uuid on the session; edits update
/// (delete + re-save, same session identity); session deletion deletes the
/// HKWorkout. Permission is requested at first workout completion, and the
/// app is fully functional when denied.
@MainActor
final class HealthKitExporter {
    private let store = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private var shareTypes: Set<HKSampleType> { [HKObjectType.workoutType()] }
    private var readTypes: Set<HKObjectType> {
        [
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.bodyMass),
            HKQuantityType(.bodyFatPercentage),
        ]
    }

    /// Requested lazily at first completion (§4b), never at launch.
    func requestAuthorizationIfNeeded() async -> Bool {
        guard isAvailable else { return false }
        return (try? await store.requestAuthorization(toShare: shareTypes, read: readTypes)) != nil
    }

    /// Save or update the HKWorkout for a completed session. Returns the
    /// HKWorkout uuid to store on `WorkoutSession.healthKitUUID`.
    func export(name: String, startedAt: Date, endedAt: Date,
                totalVolumeKg: Double, existingUUID: UUID?) async throws -> UUID? {
        guard isAvailable else { return existingUUID }

        // Guard: an edit updates rather than inserts — delete the prior
        // workout first, then re-save with the same session metadata.
        if let existingUUID {
            try? await deleteWorkout(uuid: existingUUID)
        }

        let config = HKWorkoutConfiguration()
        config.activityType = .traditionalStrengthTraining
        let builder = HKWorkoutBuilder(healthStore: store, configuration: config, device: .local())
        try await builder.beginCollection(at: startedAt)
        try await builder.addMetadata([
            HKMetadataKeyWorkoutBrandName: "RepSetForge",
            "RepSetForgeVolumeKg": totalVolumeKg,
            "RepSetForgeSessionName": name,
        ])
        try await builder.endCollection(at: endedAt)
        let workout = try await builder.finishWorkout()
        return workout?.uuid
    }

    /// Delete propagation: removing a session removes its HKWorkout.
    func deleteWorkout(uuid: UUID) async throws {
        guard isAvailable else { return }
        let predicate = HKQuery.predicateForObject(with: uuid)
        let samples: [HKSample] = try await withCheckedThrowingContinuation { cont in
            let q = HKSampleQuery(sampleType: .workoutType(), predicate: predicate,
                                  limit: 1, sortDescriptors: nil) { _, samples, error in
                if let error { cont.resume(throwing: error) } else { cont.resume(returning: samples ?? []) }
            }
            store.execute(q)
        }
        guard let workout = samples.first else { return }
        try await store.delete(workout)
    }
}
