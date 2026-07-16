import Foundation
import HealthKit

/// Phone-only Apple Health export (dev spec §4b) — the Watch companion's
/// mirrored `HKWorkoutSession` (real HR/energy telemetry) is v1.1 and not
/// built yet, so this always takes the phone-only estimated-energy path.
///
/// **Simplification**: does not add per-exercise `HKWorkoutActivity`
/// segments (the "iOS 16+ ... so Fitness shows the breakdown" enhancement
/// dev spec §4b mentions) — that API needs careful async
/// begin/end-per-activity sequencing that can't be verified against a real
/// compiler in this environment, and getting it wrong risks corrupting the
/// whole workout save. The core save (activity type, start/end, estimated
/// energy, metadata, duplicate-write guard) is implemented; the segment
/// breakdown is left for a pass with a real device/simulator to verify against.
///
/// No macOS/Xcode toolchain exists in this environment, so none of this has
/// been compiled or run — reviewed carefully by hand against the modern
/// (iOS 17+) async `HKWorkoutBuilder` API, but treat it as unverified until
/// a real build confirms it.
enum HealthKitExportService {
    private static let healthStore = HKHealthStore()

    private static var shareTypes: Set<HKSampleType> {
        var types: Set<HKSampleType> = [HKObjectType.workoutType()]
        if let energy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(energy)
        }
        return types
    }

    private static var readTypes: Set<HKObjectType> {
        let identifiers: [HKQuantityTypeIdentifier] = [.heartRate, .activeEnergyBurned, .bodyMass, .bodyFatPercentage]
        return Set(identifiers.compactMap { HKObjectType.quantityType(forIdentifier: $0) })
    }

    /// "Request share authorization (workouts, active energy) and read
    /// (heart rate, energy) at first workout completion, not onboarding" —
    /// call this from the Summary screen, not app launch. Returns whether
    /// workout-sharing is authorized (what `saveWorkout` actually needs);
    /// read authorization can't be introspected the same way, per HealthKit's
    /// privacy model (read grants aren't reported back to the app).
    static func requestAuthorizationIfNeeded() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        do {
            try await healthStore.requestAuthorization(toShare: shareTypes, read: readTypes)
        } catch {
            return false
        }
        return healthStore.authorizationStatus(for: HKObjectType.workoutType()) == .sharingAuthorized
    }

    /// Builds and saves an `HKWorkout` for a completed session. Returns the
    /// saved workout's `uuid` (to store on `WorkoutSession.healthKitUUID` as
    /// the duplicate-write guard) or `nil` on any failure/no-op. A session
    /// that already has a `healthKitUUID` is treated as already saved and
    /// returned as-is without a second write — updating an existing
    /// `HKWorkout` (the historical-edit invalidation chain's "delete +
    /// re-save" path, dev spec §5) isn't built yet since there's no way to
    /// edit a completed session at all.
    static func saveWorkout(session: WorkoutSession, bodyweightKg: Decimal?) async -> UUID? {
        if let existing = session.healthKitUUID { return existing }
        guard HKHealthStore.isHealthDataAvailable() else { return nil }
        guard let endedAt = session.endedAt else { return nil }
        guard healthStore.authorizationStatus(for: HKObjectType.workoutType()) == .sharingAuthorized else { return nil }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining

        let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: configuration, device: .local())

        do {
            try await builder.beginCollection(at: session.startedAt)

            if let energySample = estimatedEnergySample(session: session, bodyweightKg: bodyweightKg) {
                try await builder.addSamples([energySample])
            }

            let (totalVolume, setCount) = sessionTotals(session)
            try await builder.addMetadata([
                HKMetadataKeyWorkoutBrandName: "RepSetForge",
                "RepSetForgeTotalVolumeKg": NSDecimalNumber(decimal: totalVolume).doubleValue,
                "RepSetForgeSetCount": setCount,
            ])

            try await builder.endCollection(at: endedAt)
            let workout = try await builder.finishWorkout()
            return workout?.uuid
        } catch {
            return nil
        }
    }

    /// Historical edit invalidation chain step 4 (dev spec §5): "update the
    /// linked HKWorkout via healthKitUUID (delete + re-save with
    /// same-session metadata)". `HKWorkoutBuilder` has no in-place update
    /// API, so this is a real delete-then-recreate; `saveWorkout` early-
    /// returns the existing UUID otherwise, so `healthKitUUID` has to be
    /// cleared first or the re-save would silently no-op.
    static func resaveWorkout(session: WorkoutSession, bodyweightKg: Decimal?) async -> UUID? {
        if let existing = session.healthKitUUID {
            deleteWorkout(uuid: existing)
            session.healthKitUUID = nil
        }
        return await saveWorkout(session: session, bodyweightKg: bodyweightKg)
    }

    /// Deleting a session deletes its `HKWorkout` (dev spec §4b/§5) — this
    /// is a best-effort fire-and-forget; there's nothing useful to surface
    /// to the user if it fails (the local session record is already gone).
    static func deleteWorkout(uuid: UUID) {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let predicate = HKQuery.predicateForObject(with: uuid)
        let query = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: predicate, limit: 1, sortDescriptors: nil) { _, samples, _ in
            guard let workout = samples?.first else { return }
            healthStore.delete(workout) { _, _ in }
        }
        healthStore.execute(query)
    }

    /// "Phone-only sessions estimate kcal (MET 5.0 × bodyweight × duration)"
    /// (dev spec §4b). Falls back to a 75kg estimate when no `BodyMetric`
    /// has ever been logged, rather than skipping the energy sample entirely.
    private static func estimatedEnergySample(session: WorkoutSession, bodyweightKg: Decimal?) -> HKQuantitySample? {
        guard let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
              let endedAt = session.endedAt else { return nil }
        let bodyweight = NSDecimalNumber(decimal: bodyweightKg ?? 75).doubleValue
        let durationHours = endedAt.timeIntervalSince(session.startedAt) / 3600
        let kcal = 5.0 * bodyweight * durationHours
        let quantity = HKQuantity(unit: .kilocalorie(), doubleValue: kcal)
        return HKQuantitySample(type: energyType, quantity: quantity, start: session.startedAt, end: endedAt)
    }

    private static func sessionTotals(_ session: WorkoutSession) -> (volumeKg: Decimal, setCount: Int) {
        let completedSets = session.sessionExercises.flatMap(\.setEntries)
            .filter { $0.completedAt != nil && $0.type.countsTowardVolumeAndPRs }
        let volume = completedSets.compactMap(\.volumeKg).reduce(Decimal(0), +)
        return (volume, completedSets.count)
    }
}
