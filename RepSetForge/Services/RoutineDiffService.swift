import Foundation

/// Post-workout routine-update diff (dev spec §5: "diff session vs. template
/// (weights, added/removed exercises, set counts). If diff non-empty → sheet
/// with per-change toggles, default on for weight changes, off for
/// structural changes.").
///
/// **Simplification**: `RoutineItem` has no stored target-weight field (the
/// data model only carries rep-range targets — see dev spec §2), so there's
/// nothing to diff a "weight change" against; that category isn't
/// implemented here. Every change this produces is structural (exercise
/// added/removed, set count changed), so — per the spec's own stated
/// default for structural changes — every toggle defaults off.
enum RoutineDiffService {
    struct Change: Identifiable {
        enum Kind: Equatable {
            case exerciseAdded(setCount: Int)
            case exerciseRemoved
            case setCountChanged(from: Int, to: Int)
        }

        let exercise: Exercise
        let kind: Kind

        /// Deterministic (not a random UUID) so repeated `diff()` calls against
        /// unchanged data produce stable identity for SwiftUI list diffing.
        var id: String {
            switch kind {
            case .exerciseAdded: return "\(exercise.id)-added"
            case .exerciseRemoved: return "\(exercise.id)-removed"
            case .setCountChanged: return "\(exercise.id)-setcount"
            }
        }
    }

    static func diff(session: WorkoutSession, routine: Routine) -> [Change] {
        var changes: [Change] = []
        let routineExerciseIDs = Set(routine.items.compactMap { $0.exercise?.id })
        let sessionExercisesByExerciseID = Dictionary(grouping: session.sessionExercises) { $0.exercise?.id }

        for sessionExercise in session.sessionExercises {
            guard let exercise = sessionExercise.exercise else { continue }
            if !routineExerciseIDs.contains(exercise.id) {
                let setCount = completedSetCount(sessionExercise)
                guard setCount > 0 else { continue }
                changes.append(Change(exercise: exercise, kind: .exerciseAdded(setCount: setCount)))
            }
        }

        for item in routine.items {
            guard let exercise = item.exercise else { continue }
            guard let matches = sessionExercisesByExerciseID[exercise.id] else {
                changes.append(Change(exercise: exercise, kind: .exerciseRemoved))
                continue
            }
            let performedCount = matches.reduce(0) { $0 + completedSetCount($1) }
            if performedCount > 0 && performedCount != item.targetSets {
                changes.append(Change(exercise: exercise, kind: .setCountChanged(from: item.targetSets, to: performedCount)))
            }
        }

        return changes
    }

    private static func completedSetCount(_ sessionExercise: SessionExercise) -> Int {
        sessionExercise.setEntries.filter { $0.completedAt != nil && $0.type.countsTowardVolumeAndPRs }.count
    }
}
