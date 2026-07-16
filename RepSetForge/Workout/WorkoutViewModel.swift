import Foundation
import SwiftData
import SwiftUI
import Observation

/// Central state for the Active Workout screen (§3). Owns the completion
/// flow, ghost resolution inputs, chart-collapse map, and telemetry. The
/// current rest countdown lives only in the bottom pill via RestTimerManager.
@Observable
@MainActor
final class WorkoutViewModel {
    let store: ActiveSessionStore
    let restTimer = RestTimerManager()
    var page: Int = 0
    /// Per-exercise-per-session chart expansion; absent = expanded until first set.
    var chartOpen: [Int: Bool] = [:]
    /// Row indices flagged touched per page ("p-i").
    private var touchedKeys: Set<String> = []
    var prFlashSetID: UUID?

    init(store: ActiveSessionStore) {
        self.store = store
    }

    var session: WorkoutSession? { store.session }

    var orderedExercises: [SessionExercise] {
        (session?.exercises ?? []).sorted { $0.order < $1.order }
    }

    func orderedSets(_ ex: SessionExercise) -> [SetEntry] {
        (ex.sets ?? []).sorted { $0.index < $1.index }
    }

    // MARK: telemetry (one rest ledger → WORK + REST = SESSION)

    var totalSets: Int { orderedExercises.reduce(0) { $0 + ($1.sets?.count ?? 0) } }
    var doneSets: Int {
        orderedExercises.reduce(0) { $0 + ($1.sets ?? []).filter { $0.completedAt != nil }.count }
    }
    var volumeKg: Decimal {
        orderedExercises.reduce(0) { acc, ex in
            acc + (ex.sets ?? [])
                .filter { $0.completedAt != nil && $0.type != .warmup }
                .reduce(Decimal(0)) { $0 + StrengthMath.volumeKg(weightKg: $1.weightKg, reps: $1.reps) }
        }
    }

    // MARK: ghost inheritance

    func touchedKey(page: Int, row: Int) -> String { "\(page)-\(row)" }

    func markTouched(page: Int, row: Int) {
        touchedKeys.insert(touchedKey(page: page, row: row))
        store.touch()
    }

    func isTouched(page: Int, row: Int) -> Bool {
        touchedKeys.contains(touchedKey(page: page, row: row))
    }

    /// Resolve display values for a page's set table.
    func resolvedRows(pageIndex: Int, exercise: SessionExercise,
                      previous: [GhostResolver.RowValues]) -> [GhostResolver.Resolved] {
        let sets = orderedSets(exercise)
        let rows = sets.map { GhostResolver.RowValues(weightKg: $0.weightKg, reps: $0.reps, rpe: $0.rpe) }
        let touched = sets.enumerated().map { i, s in
            s.completedAt != nil || isTouched(page: pageIndex, row: i)
        }
        return GhostResolver.resolve(rows: rows, touched: touched, previous: previous)
    }

    // MARK: chart collapse (§3.3)

    func chartExpanded(pageIndex: Int, exercise: SessionExercise) -> Bool {
        if let explicit = chartOpen[pageIndex] { return explicit }
        let anyDone = (exercise.sets ?? []).contains { $0.completedAt != nil }
        return !anyDone
    }

    // MARK: completion flow (§3 behavior contract #3–4)

    struct CompletionOutcome {
        var isPR: Bool
        var startedRestSeconds: Int?
    }

    /// Tap ✓: commit resolved ghosts as real, stamp completedAt, PR check,
    /// start rest, append next row if last. Haptics/animation are view-side.
    @discardableResult
    func complete(pageIndex: Int, exercise: SessionExercise, rowIndex: Int,
                  resolved: GhostResolver.Resolved,
                  restSeconds: Int,
                  bestWeight: Decimal?, bestReps: Int?) -> CompletionOutcome {
        let sets = orderedSets(exercise)
        guard sets.indices.contains(rowIndex) else { return .init(isPR: false, startedRestSeconds: nil) }
        let set = sets[rowIndex]

        if set.completedAt != nil {
            // Un-complete (prototype parity): clears the flag, keeps values.
            set.completedAt = nil
            set.isPR = false
            store.touch()
            return .init(isPR: false, startedRestSeconds: nil)
        }

        set.weightKg = resolved.values.weightKg
        set.reps = resolved.values.reps
        set.rpe = resolved.values.rpe
        set.completedAt = .now
        markTouched(page: pageIndex, row: rowIndex)

        // PR check against current bests (full PRRecord integration in Phase 6/7;
        // rebuild stays authoritative via PRRebuilder).
        var isPR = false
        if set.type != .warmup, let w = set.weightKg, let r = set.reps {
            if let bw = bestWeight {
                isPR = w > bw || (w == bw && r > (bestReps ?? 0))
            } else {
                isPR = false // no history: first sets are baselines, not PRs
            }
        }
        set.isPR = isPR
        if isPR { prFlashSetID = set.id }

        // Last row → append the next (inherits via ghost resolution).
        if rowIndex == sets.count - 1 {
            let next = SetEntry(index: set.index + 1, type: set.type == .warmup ? .working : set.type)
            next.sessionExercise = exercise
            exercise.sets?.append(next)
        }

        restTimer.start(duration: TimeInterval(restSeconds))
        store.touch()
        return .init(isPR: isPR, startedRestSeconds: restSeconds)
    }

    func addSet(to exercise: SessionExercise) {
        let sets = orderedSets(exercise)
        let next = SetEntry(index: (sets.last?.index ?? -1) + 1,
                            type: sets.last.map { $0.type == .warmup ? .working : $0.type } ?? .working)
        next.sessionExercise = exercise
        exercise.sets?.append(next)
        store.touch()
    }

    func deleteSet(_ set: SetEntry, from exercise: SessionExercise) {
        exercise.sets?.removeAll { $0.id == set.id }
        store.touch()
    }

    /// Coaching-prompt apply (§3.4): write the target into all pending
    /// non-warmup sets.
    func applyTarget(exercise: SessionExercise, pageIndex: Int,
                     weightKg: Decimal, reps: Int, rpe: Double?) {
        for (i, s) in orderedSets(exercise).enumerated() where s.completedAt == nil && s.type != .warmup {
            s.weightKg = weightKg
            s.reps = reps
            if let rpe { s.rpe = rpe }
            markTouched(page: pageIndex, row: i)
        }
        store.touch()
    }
}
