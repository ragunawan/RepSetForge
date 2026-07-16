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

    /// Historical edit invalidation chain step 1 (dev spec §5): "PRRecords
    /// are derived data... rebuild them from the full SetEntry history for
    /// that exercise... cascade: any *later* set that becomes/stops being a
    /// PR gets its denormalized isPR flag updated."
    ///
    /// `isPR` is a historical badge ("this set was a PR when it was logged"),
    /// not a live "currently holds the record" indicator — `evaluate(...)`
    /// above only ever sets it `true` going forward, never clears it. So a
    /// correct rebuild has to replay the *entire* chronological history from
    /// scratch (not just re-derive the current bests): walk every qualifying
    /// set for the exercise in `completedAt` order, tracking the running
    /// best per kind, and mark `isPR` on exactly the sets that improved on
    /// the running best at the time — this is what makes an edit to an
    /// *earlier* set correctly un-PR a *later* one that only ever beat the
    /// old (now-lower, or now-nonexistent-because-deleted) value.
    static func recompute(
        exercise: Exercise,
        allSets: [SetEntry],
        existingRecords: [PRRecord],
        context: ModelContext
    ) {
        let qualifying = allSets
            .filter { $0.completedAt != nil && $0.type.countsTowardVolumeAndPRs && $0.sessionExercise?.exercise?.id == exercise.id }
            .sorted { $0.completedAt! < $1.completedAt! }

        var best: [PRKind: (value: Decimal, set: SetEntry)] = [:]

        for set in qualifying {
            var isPR = false

            if let weight = set.weightKg, best[.bestWeight].map({ weight > $0.value }) ?? true {
                best[.bestWeight] = (weight, set)
                isPR = true
            }
            if let e1rm = set.estimatedOneRepMax, best[.bestE1RM].map({ e1rm > $0.value }) ?? true {
                best[.bestE1RM] = (e1rm, set)
                isPR = true
            }
            if let volume = set.volumeKg, best[.bestVolume].map({ volume > $0.value }) ?? true {
                best[.bestVolume] = (volume, set)
                isPR = true
            }

            set.isPR = isPR
        }

        // Any exercise set that got edited/deleted out of `qualifying`
        // (e.g. weight cleared, or the set itself removed) simply never has
        // its `isPR` touched by the loop above — callers are expected to
        // have already applied the edit/delete before calling `recompute`,
        // so a no-longer-qualifying set keeps whatever stale `isPR` value it
        // had. That's fine for a *deleted* set (nothing left to display),
        // but a set edited to no longer qualify (e.g. weight cleared) would
        // keep a stale badge — narrow enough (requires un-completing a
        // historical set's weight, not just changing its value) that it's
        // left as a known edge case rather than adding a second full pass.
        // Mirrors evaluate()'s scope exactly — .repsAtWeight isn't
        // implemented there either (see this file's top doc comment), so
        // recompute() must not touch it (PRKind.allCases would include it).
        for kind: PRKind in [.bestWeight, .bestE1RM, .bestVolume] {
            let existing = existingRecords.first { $0.kind == kind }
            guard let winner = best[kind] else {
                if let existing { context.delete(existing) }
                continue
            }
            if let existing {
                existing.value = winner.value
                existing.setEntry = winner.set
                existing.achievedAt = winner.set.completedAt ?? .now
            } else {
                let record = PRRecord(exercise: exercise, kind: kind, value: winner.value, setEntry: winner.set, achievedAt: winner.set.completedAt ?? .now)
                context.insert(record)
            }
        }
    }
}
