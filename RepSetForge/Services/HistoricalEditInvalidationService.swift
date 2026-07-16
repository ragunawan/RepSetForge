import Foundation
import SwiftData

/// Historical edit invalidation chain (dev spec §5): "editing or deleting a
/// past session triggers, in order: (1) PR recompute... (2) ladder
/// recompute... (3) weekly rollup invalidation... (4) Health re-write."
///
/// Steps 2 and 3 need no code here: `ProgressionLadderService` and
/// `HomeStatsService`/`ProgressStatsService` are pure functions recomputed
/// live from `@Query`-fetched source data on every render — nothing in this
/// codebase caches a ladder position or a weekly rollup, so there's nothing
/// to invalidate. Only step 1 (`PRRecord`/`SetEntry.isPR`, both denormalized)
/// and step 4 (the linked `HKWorkout`) are actual derived *state* that can
/// go stale, so those are the only two this orchestrates.
enum HistoricalEditInvalidationService {
    static func run(
        session: WorkoutSession,
        touchedExercises: [Exercise],
        allSetEntries: [SetEntry],
        allPRRecords: [PRRecord],
        bodyweightKg: Decimal?,
        context: ModelContext
    ) async {
        for exercise in touchedExercises {
            let existingRecords = allPRRecords.filter { $0.exercise?.id == exercise.id }
            PersonalRecordService.recompute(exercise: exercise, allSets: allSetEntries, existingRecords: existingRecords, context: context)
        }

        if session.healthKitUUID != nil {
            _ = await HealthKitExportService.resaveWorkout(session: session, bodyweightKg: bodyweightKg)
        }
    }
}
