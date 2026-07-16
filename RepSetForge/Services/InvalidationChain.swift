import Foundation
import SwiftData

/// §6 historical-edit invalidation chain: after editing/deleting a past
/// session, run (1) PR recompute per touched exercise, (2) ladder recompute
/// (implicit — LadderEngine reads history live, nothing stored), (3) weekly
/// rollup invalidation, (4) Health re-write via healthKitUUID. One background
/// transaction; derived data is never edited directly.
@MainActor
enum InvalidationChain {
    /// Rebuild PRRecords + isPR flags for one exercise from full history.
    static func recomputePRs(exercise: Exercise, context: ModelContext) throws {
        let exID = exercise.id
        // All set entries for this exercise across all sessions.
        let all = try context.fetch(FetchDescriptor<SetEntry>())
        let mine = all.filter { $0.sessionExercise?.exercise?.id == exID }

        let snapshots = mine.map {
            PRRebuilder.SetSnapshot(id: $0.id, type: $0.type, weightKg: $0.weightKg,
                                    reps: $0.reps, completedAt: $0.completedAt)
        }
        let result = PRRebuilder.rebuild(history: snapshots)

        // Cascade the denormalized flags (later sets can become/stop being PRs).
        for set in mine {
            set.isPR = result.prSetIDs.contains(set.id)
        }

        // Replace this exercise's PRRecords wholesale — they are outputs only.
        let existing = try context.fetch(FetchDescriptor<PRRecord>())
            .filter { $0.exercise?.id == exID }
        existing.forEach(context.delete)
        for r in result.records {
            let record = PRRecord(kind: r.kind, value: r.value, achievedAt: r.achievedAt)
            record.exercise = exercise
            record.setEntry = mine.first { $0.id == r.setID }
            context.insert(record)
        }
    }

    /// Full chain for an edited/deleted session. `healthExporter` is optional
    /// so the chain works with Health denied.
    static func run(touchedExercises: [Exercise], editedSession: WorkoutSession?,
                    context: ModelContext, health: HealthKitExporter?) async {
        for exercise in touchedExercises {
            try? recomputePRs(exercise: exercise, context: context)
        }
        // (2) ladder: derived live by LadderEngine.regenerate — no stored state.
        // (3) rollups: Progress charts recompute from SetEntry per render (v1
        //     computes buckets on demand; nothing cached to invalidate yet).
        // (4) Health re-write.
        if let session = editedSession, let health {
            if session.status == .completed, let ended = session.endedAt {
                let volume = (session.exercises ?? [])
                    .flatMap { $0.sets ?? [] }
                    .filter { $0.completedAt != nil && $0.type != .warmup }
                    .reduce(Decimal(0)) { $0 + StrengthMath.volumeKg(weightKg: $1.weightKg, reps: $1.reps) }
                let uuid = try? await health.export(
                    name: session.name, startedAt: session.startedAt, endedAt: ended,
                    totalVolumeKg: NSDecimalNumber(decimal: volume).doubleValue,
                    existingUUID: session.healthKitUUID)
                if let uuid { session.healthKitUUID = uuid }
            }
        }
        try? context.save()
    }

    /// Session deletion: propagate the HKWorkout delete, then recompute PRs
    /// for every exercise the session touched.
    static func deleteSession(_ session: WorkoutSession, context: ModelContext,
                              health: HealthKitExporter?) async {
        let touched = (session.exercises ?? []).compactMap(\.exercise)
        if let uuid = session.healthKitUUID, let health {
            try? await health.deleteWorkout(uuid: uuid)
        }
        context.delete(session)
        for exercise in touched {
            try? recomputePRs(exercise: exercise, context: context)
        }
        try? context.save()
    }
}
