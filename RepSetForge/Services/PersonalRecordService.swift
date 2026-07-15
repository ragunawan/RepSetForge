import Foundation
import SwiftData

/// PR detection on set commit (dev spec §3 "PR check on commit"). Compares a
/// just-completed set against the exercise's existing `PRRecord`s and
/// inserts/updates a record when it's a new best. Warm-up sets never qualify
/// (`SetType.countsTowardVolumeAndPRs`).
///
/// `.repsAtWeight` (best reps logged at a specific weight) needs a record
/// keyed by weight rather than one best-per-kind record and isn't
/// implemented yet — TODO.md.
enum PersonalRecordService {
    @discardableResult
    static func evaluate(
        set: SetEntry,
        exercise: Exercise,
        existingRecords: [PRRecord],
        context: ModelContext
    ) -> [PRRecord] {
        guard set.type.countsTowardVolumeAndPRs, let weight = set.weightKg, let reps = set.reps, reps > 0 else {
            return []
        }

        var newRecords: [PRRecord] = []

        func bestValue(for kind: PRKind) -> Decimal? {
            existingRecords.first { $0.kind == kind }?.value
        }

        func upsert(kind: PRKind, value: Decimal) {
            if let existing = existingRecords.first(where: { $0.kind == kind }) {
                existing.value = value
                existing.setEntry = set
                existing.achievedAt = set.completedAt ?? .now
                newRecords.append(existing)
            } else {
                let record = PRRecord(exercise: exercise, kind: kind, value: value, setEntry: set, achievedAt: set.completedAt ?? .now)
                context.insert(record)
                newRecords.append(record)
            }
        }

        if bestValue(for: .bestWeight).map({ weight > $0 }) ?? true {
            upsert(kind: .bestWeight, value: weight)
        }

        if let e1rm = set.estimatedOneRepMax, bestValue(for: .bestE1RM).map({ e1rm > $0 }) ?? true {
            upsert(kind: .bestE1RM, value: e1rm)
        }

        if let volume = set.volumeKg, bestValue(for: .bestVolume).map({ volume > $0 }) ?? true {
            upsert(kind: .bestVolume, value: volume)
        }

        set.isPR = !newRecords.isEmpty
        return newRecords
    }
}
