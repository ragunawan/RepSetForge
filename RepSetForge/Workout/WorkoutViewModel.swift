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
    let liveActivity = LiveActivityController()
    var page: Int = 0 {
        didSet { if page != oldValue { pushActivityUpdate() } }
    }
    /// Per-exercise-per-session chart expansion; absent = expanded until first set.
    var chartOpen: [Int: Bool] = [:]
    /// Row indices flagged touched per page ("p-i").
    private var touchedKeys: Set<String> = []
    var prFlashSetID: UUID?

    init(store: ActiveSessionStore) {
        self.store = store
        // Rest transitions (§4): update the activity and manage the
        // rest-complete notification; intents from the lock screen route back
        // through the bridge into the same manager.
        restTimer.onStateChange = { [weak self] in
            guard let self else { return }
            if let end = restTimer.plannedEnd {
                liveActivity.scheduleRestNotification(endingAt: end, exerciseName: pageTitle(page))
            } else {
                liveActivity.cancelRestNotification()
            }
            pushActivityUpdate()
        }
        RestIntentBridge.shared.skip = { [weak self] in self?.restTimer.skip() }
        RestIntentBridge.shared.extend = { [weak self] in self?.restTimer.extend($0) }
    }

    // MARK: Live Activity lifecycle (§4)

    func startLiveActivity() {
        guard let session else { return }
        liveActivity.start(workoutName: session.name, startDate: session.startedAt,
                           state: activityContentState())
    }

    func endLiveActivity(discarded: Bool) {
        liveActivity.cancelRestNotification()
        liveActivity.end(finalState: discarded ? nil : activityContentState(),
                         immediate: discarded)
    }

    func reassertLiveActivityOnForeground() {
        guard let session else { return }
        liveActivity.reassertIfNeeded(workoutName: session.name,
                                      startDate: session.startedAt,
                                      state: activityContentState())
    }

    func pushActivityUpdate() {
        liveActivity.update(activityContentState())
    }

    var session: WorkoutSession? { store.session }

    var orderedExercises: [SessionExercise] {
        (session?.exercises ?? []).sorted { $0.order < $1.order }
    }

    // MARK: superset pages (§3 resolved model — a group occupies one page)

    /// Adjacent exercises sharing a groupID collapse into one page.
    var pages: [[SessionExercise]] {
        var out: [[SessionExercise]] = []
        for ex in orderedExercises {
            if let gid = ex.groupID, let last = out.last, last.first?.groupID == gid {
                out[out.count - 1].append(ex)
            } else {
                out.append([ex])
            }
        }
        return out
    }

    func pageTitle(_ index: Int) -> String {
        guard pages.indices.contains(index) else { return "" }
        let members = pages[index]
        if members.count > 1 { return "Superset" }
        return members.first?.exercise?.name ?? ""
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

    // MARK: history feeds (ghost seed + per-item rest)

    private var previousRowsCache: [UUID: [GhostResolver.RowValues]] = [:]

    /// The previous completed session's set values for this exercise —
    /// first-row ghost seed (§3 contract #1). Cached per exercise for the
    /// life of the active session.
    func previousRows(for exercise: SessionExercise) -> [GhostResolver.RowValues] {
        guard let exID = exercise.exercise?.id else { return [] }
        if let cached = previousRowsCache[exID] { return cached }
        guard let context = store.context else { return [] }
        let completed = SessionStatus.completed.rawValue
        let fd = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.statusRaw == completed },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        let currentID = session?.id
        let prev = ((try? context.fetch(fd)) ?? [])
            .first { s in
                s.id != currentID &&
                (s.exercises ?? []).contains { $0.exercise?.id == exID }
            }?
            .exercises?.first { $0.exercise?.id == exID }
        let rows: [GhostResolver.RowValues] = prev.map { p in
            (p.sets ?? []).sorted { $0.index < $1.index }
                .filter { $0.completedAt != nil }
                .map { .init(weightKg: $0.weightKg, reps: $0.reps, rpe: $0.rpe) }
        } ?? []
        previousRowsCache[exID] = rows
        return rows
    }

    /// Rest for an exercise: its RoutineItem's restSeconds when the session
    /// came from a routine, else the profile default, else 120 s.
    func restSeconds(for exercise: SessionExercise) -> Int {
        let exID = exercise.exercise?.id
        if let items = session?.routine?.orderedItems,
           let item = items.first(where: { $0.exercise?.id == exID }) {
            return item.restSeconds
        }
        if let context = store.context,
           let profile = try? context.fetch(FetchDescriptor<UserProfile>()).first {
            return profile.defaultRestSeconds
        }
        return 120
    }

    // MARK: ghost inheritance

    /// Keyed per session-exercise (a superset page holds several tables, so
    /// page index alone would collide).
    func touchedKey(exercise: SessionExercise, row: Int) -> String {
        "\(ObjectIdentifier(exercise).hashValue)-\(row)"
    }

    func markTouched(exercise: SessionExercise, row: Int) {
        touchedKeys.insert(touchedKey(exercise: exercise, row: row))
        store.touch()
    }

    func isTouched(exercise: SessionExercise, row: Int) -> Bool {
        touchedKeys.contains(touchedKey(exercise: exercise, row: row))
    }

    /// Resolve display values for a set table, seeded from the previous
    /// session's history.
    func resolvedRows(exercise: SessionExercise) -> [GhostResolver.Resolved] {
        let sets = orderedSets(exercise)
        let rows = sets.map { GhostResolver.RowValues(weightKg: $0.weightKg, reps: $0.reps, rpe: $0.rpe) }
        let touched = sets.enumerated().map { i, s in
            s.completedAt != nil || isTouched(exercise: exercise, row: i)
        }
        return GhostResolver.resolve(rows: rows, touched: touched,
                                     previous: previousRows(for: exercise))
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
    /// `startRest: false` for non-final superset members (§3: intra-superset
    /// transition is immediate; only the round's last member starts the timer).
    @discardableResult
    func complete(exercise: SessionExercise, rowIndex: Int,
                  resolved: GhostResolver.Resolved,
                  restSeconds: Int,
                  bestWeight: Decimal?, bestReps: Int?,
                  startRest: Bool = true) -> CompletionOutcome {
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
        markTouched(exercise: exercise, row: rowIndex)

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

        if startRest {
            restTimer.start(duration: TimeInterval(restSeconds))
        }
        store.touch()
        pushActivityUpdate()
        return .init(isPR: isPR, startedRestSeconds: startRest ? restSeconds : nil)
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
    func applyTarget(exercise: SessionExercise,
                     weightKg: Decimal, reps: Int, rpe: Double?) {
        for (i, s) in orderedSets(exercise).enumerated() where s.completedAt == nil && s.type != .warmup {
            s.weightKg = weightKg
            s.reps = reps
            if let rpe { s.rpe = rpe }
            markTouched(exercise: exercise, row: i)
        }
        store.touch()
    }
}
