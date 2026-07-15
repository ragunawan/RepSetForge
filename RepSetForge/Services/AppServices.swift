import Foundation
@preconcurrency import ActivityKit
import HealthKit
import SwiftData
import SwiftUI
import UserNotifications

struct RestorePolicy {
    func decision(for session: WorkoutSession?, now: Date = Date()) -> RestoreDecision {
        guard let session, session.status == .active else { return .none }
        let age = now.timeIntervalSince(session.startedAt)
        if age < 4 * 60 * 60 { return .silentResume }
        return .needsResolution(reason: "Unfinished workout — \(session.name), started \(session.startedAt.formatted(date: .omitted, time: .shortened)), \(session.completedSetCount) sets logged")
    }
}

struct RestTimerState: Equatable {
    var startedAt: Date
    var duration: TimeInterval
    var skipped: Bool = false

    var endDate: Date { startedAt.addingTimeInterval(duration) }
    func remaining(at now: Date = Date()) -> TimeInterval { max(0, endDate.timeIntervalSince(now)) }
    func overtime(at now: Date = Date()) -> TimeInterval { max(0, now.timeIntervalSince(endDate)) }
    func progress(at now: Date = Date()) -> Double {
        guard duration > 0 else { return 1 }
        return min(1, max(0, now.timeIntervalSince(startedAt) / duration))
    }
}

@MainActor final class RestTimerManager: ObservableObject {
    @Published private(set) var state: RestTimerState?
    private let scheduler: RestNotificationScheduling

    init(scheduler: RestNotificationScheduling = LocalRestNotificationScheduler()) {
        self.scheduler = scheduler
    }

    func start(duration: TimeInterval, now: Date = Date()) {
        state = RestTimerState(startedAt: now, duration: duration)
        Task { await scheduler.scheduleRestComplete(after: duration) }
    }

    func extend(seconds: TimeInterval = 30) {
        guard var current = state else { return }
        current.duration += seconds
        state = current
        Task { await scheduler.scheduleRestComplete(after: current.remaining()) }
    }

    func skip() {
        state = nil
        Task { await scheduler.cancelRestComplete() }
    }
}

@MainActor protocol RestNotificationScheduling {
    func scheduleRestComplete(after seconds: TimeInterval) async
    func cancelRestComplete() async
}

@MainActor final class LocalRestNotificationScheduler: RestNotificationScheduling {
    private let identifier = "repsetforge.rest.complete"
    private let warningIdentifier = "repsetforge.rest.warning"

    func scheduleRestComplete(after seconds: TimeInterval) async {
        guard seconds >= 1 else { return }
        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
        center.removePendingNotificationRequests(withIdentifiers: [identifier, warningIdentifier])

        if seconds > 10 {
            let warningContent = UNMutableNotificationContent()
            warningContent.title = "10 seconds left"
            warningContent.body = "Get ready for your next set."
            warningContent.sound = .default

            let warningTrigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds - 10, repeats: false)
            let warningRequest = UNNotificationRequest(identifier: warningIdentifier, content: warningContent, trigger: warningTrigger)
            try? await center.add(warningRequest)
        }

        let content = UNMutableNotificationContent()
        content.title = "Rest complete"
        content.body = "Start your next set when ready."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try? await center.add(request)
    }

    func cancelRestComplete() async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier, warningIdentifier])
    }
}

struct PRResult: Identifiable, Equatable {
    let id = UUID()
    let kind: String
    let value: Double
}

struct PRService {
    func evaluate(set: SetEntry, exerciseName: String, existing: [PRRecord], latestBodyweightKg: Double?) -> [PRResult] {
        guard set.type != .warmup, let reps = set.reps, reps > 0 else { return [] }
        let weight = set.type == .bodyweight ? (latestBodyweightKg ?? set.weightKg ?? 0) : (set.weightKg ?? 0)
        var candidates: [PRResult] = []
        if weight > 0 { candidates.append(PRResult(kind: "bestWeight", value: weight)) }
        candidates.append(PRResult(kind: "bestVolume", value: TrainingMath.volumeKg(weightKg: weight, reps: reps, kind: set.type, latestBodyweightKg: latestBodyweightKg)))
        if let e1rm = TrainingMath.e1RM(weightKg: weight, reps: reps) {
            candidates.append(PRResult(kind: "bestE1RM", value: e1rm))
        }
        return candidates.filter { candidate in
            let old = existing.first { $0.exerciseNameKey == TrainingMath.canonicalNameKey(exerciseName) && $0.kind == candidate.kind }
            return candidate.value > (old?.value ?? 0)
        }
    }
}

struct LadderLevel: Identifiable, Equatable {
    let id = UUID()
    let weightKg: Double
    let reps: Int
    let completed: Bool
    let current: Bool
}

struct ProgressionPrescription: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let detail: String
    let targetWeightKg: Double
    let targetReps: Int
    let targetRPE: Double?
}

struct ProgressionService {
    func prescriptions(rule: ProgressionRule, baseWeightKg: Double, recentSets: [SetEntry]) -> [ProgressionPrescription] {
        switch rule.type {
        case .ladder:
            let current = ladder(rule: rule, baseWeightKg: baseWeightKg, qualifyingSets: recentSets).first(where: \.current)
            let reps = current?.reps ?? rule.repRangeLow
            let weight = current?.weightKg ?? baseWeightKg
            return [ProgressionPrescription(title: "Current ladder level", detail: "Complete \(rule.qualifyingSetsRequired) qualifying sets at RPE <= \(rule.maxQualifyingRPE.formatted(.number.precision(.fractionLength(0...1)))).", targetWeightKg: weight, targetReps: reps, targetRPE: rule.maxQualifyingRPE)]
        case .fiveThreeOne:
            let waves: [(String, Double, Int)] = [("Week 1", 0.65, 5), ("Week 1", 0.75, 5), ("Week 1+", 0.85, 5), ("Week 2", 0.70, 3), ("Week 2", 0.80, 3), ("Week 2+", 0.90, 3), ("Week 3", 0.75, 5), ("Week 3", 0.85, 3), ("Week 3+", 0.95, 1)]
            return waves.map { wave in
                ProgressionPrescription(title: wave.0, detail: "\(Int(wave.1 * 100))% of training max", targetWeightKg: roundedPlate(rule.trainingMaxKg * wave.1, step: rule.incrementKg), targetReps: wave.2, targetRPE: nil)
            }
        case .percentageWave:
            return rule.wavePercentages.enumerated().map { index, pct in
                ProgressionPrescription(title: "Wave \(index + 1)", detail: "\(Int(pct * 100))% of training max", targetWeightKg: roundedPlate(rule.trainingMaxKg * pct, step: rule.incrementKg), targetReps: rule.repRangeLow, targetRPE: rule.maxQualifyingRPE)
            }
        case .rirAutoregulation:
            let last = recentSets.filter(\.isCompleted).sorted { ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast) }.last
            let observedRIR = last.flatMap { $0.rpe.map { max(0, 10 - $0) } }
            let adjustment: Double
            if let observedRIR, observedRIR > rule.targetRIR + 0.5 {
                adjustment = rule.rirLoadAdjustmentKg
            } else if let observedRIR, observedRIR < rule.targetRIR - 0.5 {
                adjustment = -rule.rirLoadAdjustmentKg
            } else {
                adjustment = 0
            }
            let nextWeight = max(0, (last?.weightKg ?? baseWeightKg) + adjustment)
            return [ProgressionPrescription(title: "Next autoregulated set", detail: "Target \(rule.targetRIR.formatted(.number.precision(.fractionLength(0...1)))) RIR from last-set feedback.", targetWeightKg: roundedPlate(nextWeight, step: rule.incrementKg), targetReps: last?.reps ?? rule.repRangeLow, targetRPE: 10 - rule.targetRIR)]
        }
    }

    func ladder(rule: ProgressionRule, baseWeightKg: Double, qualifyingSets: [SetEntry]) -> [LadderLevel] {
        let reps = Array(rule.repRangeLow...rule.repRangeHigh)
        let completedReps = Set(qualifyingSets.compactMap { set -> Int? in
            guard set.type == .working,
                  (set.weightKg ?? 0) >= baseWeightKg,
                  let setReps = set.reps,
                  (set.rpe ?? 10) <= rule.maxQualifyingRPE
            else { return nil }
            return setReps
        })
        var foundCurrent = false
        return reps.map { rep in
            let completed = completedReps.contains(rep)
            let current = !completed && !foundCurrent
            if current { foundCurrent = true }
            return LadderLevel(weightKg: baseWeightKg, reps: rep, completed: completed, current: current)
        } + [LadderLevel(weightKg: baseWeightKg + rule.incrementKg, reps: rule.repRangeLow, completed: false, current: !foundCurrent)]
    }

    private func roundedPlate(_ value: Double, step: Double) -> Double {
        guard step > 0 else { return value }
        return (value / step).rounded() * step
    }
}

struct WorkoutTelemetrySnapshot: Equatable {
    var heartRateBPM: Int?
    var activeEnergyKCal: Int?
    var receivedAt: Date

    func visible(at now: Date = Date(), staleness: TimeInterval = 5) -> Bool {
        now.timeIntervalSince(receivedAt) <= staleness && (heartRateBPM != nil || activeEnergyKCal != nil)
    }
}

@MainActor protocol WatchWorkoutCoordinating {
    var telemetry: WorkoutTelemetrySnapshot? { get }
    func startMirroring(session: WorkoutSession) async throws
    func completeCurrentSet() async
    func extendRest() async
    func skipRest() async
    func endMirroring() async
}

@MainActor final class LocalWatchWorkoutCoordinator: ObservableObject, WatchWorkoutCoordinating {
    @Published private(set) var telemetry: WorkoutTelemetrySnapshot?

    func startMirroring(session: WorkoutSession) async throws {}
    func completeCurrentSet() async {}
    func extendRest() async {}
    func skipRest() async {}
    func endMirroring() async { telemetry = nil }

    func ingest(heartRateBPM: Int?, activeEnergyKCal: Int?, at date: Date = Date()) {
        telemetry = WorkoutTelemetrySnapshot(heartRateBPM: heartRateBPM, activeEnergyKCal: activeEnergyKCal, receivedAt: date)
    }
}

@MainActor protocol HealthExporting {
    func requestAuthorizationIfNeeded() async -> Bool
    func saveWorkout(_ session: WorkoutSession, bodyweightKg: Double?) async throws -> UUID
    func deleteWorkout(uuid: UUID) async throws
}

@MainActor final class MockHealthExporter: HealthExporting {
    private var authorized = false

    func requestAuthorizationIfNeeded() async -> Bool {
        authorized = true
        return authorized
    }

    func saveWorkout(_ session: WorkoutSession, bodyweightKg: Double?) async throws -> UUID {
        if let existing = session.healthKitUUID { return existing }
        return UUID()
    }

    func deleteWorkout(uuid: UUID) async throws {}
}

@MainActor final class HealthKitWorkoutExporter: HealthExporting {
    private let store = HKHealthStore()

    func requestAuthorizationIfNeeded() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        let workoutType = HKObjectType.workoutType()
        let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        let share: Set<HKSampleType> = [workoutType, energyType]
        let read: Set<HKObjectType> = [
            workoutType,
            energyType,
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .bodyMass)!,
            HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage)!
        ]

        do {
            try await store.requestAuthorization(toShare: share, read: read)
            return true
        } catch {
            return false
        }
    }

    func saveWorkout(_ session: WorkoutSession, bodyweightKg: Double?) async throws -> UUID {
        guard HKHealthStore.isHealthDataAvailable() else { throw HealthExportError.unavailable }
        if let existing = session.healthKitUUID {
            try? await deleteWorkout(uuid: existing)
        }

        let start = session.startedAt
        let end = session.endedAt ?? Date()
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor

        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())
        try await builder.beginCollection(at: start)

        let durationHours = max(end.timeIntervalSince(start) / 3600, 0)
        let estimatedKCal = max(0, 5.0 * (bodyweightKg ?? 80) * durationHours)
        if estimatedKCal > 0 {
            let energy = HKQuantity(unit: .kilocalorie(), doubleValue: estimatedKCal)
            let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
            let sample = HKQuantitySample(type: energyType, quantity: energy, start: start, end: end)
            try await add(samples: [sample], to: builder)
        }

        try await builder.endCollection(at: end)
        guard let workout = try await builder.finishWorkout() else {
            throw HealthExportError.unavailable
        }
        return workout.uuid
    }

    func deleteWorkout(uuid: UUID) async throws {
        let predicate = HKQuery.predicateForObject(with: uuid)
        let descriptor = HKSampleQueryDescriptor(predicates: [.workout(predicate)], sortDescriptors: [], limit: 1)
        let workouts = try await descriptor.result(for: store)
        if let workout = workouts.first {
            try await store.delete(workout)
        }
    }

    enum HealthExportError: Error {
        case unavailable
    }

    private func add(samples: [HKSample], to builder: HKWorkoutBuilder) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.add(samples) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HealthExportError.unavailable)
                }
            }
        }
    }
}

@MainActor protocol LiveActivityCoordinating {
    func start(session: WorkoutSession) async
    func update(session: WorkoutSession, currentExercise: String?, rest: RestTimerState?) async
    func end(session: WorkoutSession, discarded: Bool) async
}

@MainActor final class NoopLiveActivityCoordinator: LiveActivityCoordinating {
    func start(session: WorkoutSession) async {}
    func update(session: WorkoutSession, currentExercise: String?, rest: RestTimerState?) async {}
    func end(session: WorkoutSession, discarded: Bool) async {}
}

@MainActor final class ActivityKitLiveActivityCoordinator: LiveActivityCoordinating {
    nonisolated(unsafe) private var activity: Activity<RepSetForgeActivityAttributes>?

    func start(session: WorkoutSession) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = RepSetForgeActivityAttributes(workoutName: session.name, startedAt: session.startedAt)
        let state = contentState(session: session, currentExercise: firstExerciseName(session), rest: nil)
        do {
            activity = try Activity.request(attributes: attributes, content: ActivityContent(state: state, staleDate: nil))
        } catch {
            activity = nil
        }
    }

    func update(session: WorkoutSession, currentExercise: String?, rest: RestTimerState?) async {
        guard let activity else { return }
        let state = contentState(session: session, currentExercise: currentExercise ?? firstExerciseName(session), rest: rest)
        await activity.update(ActivityContent(state: state, staleDate: nil))
    }

    func end(session: WorkoutSession, discarded: Bool) async {
        guard let activity else { return }
        var state = contentState(session: session, currentExercise: firstExerciseName(session), rest: nil)
        state.ended = true
        let policy: ActivityUIDismissalPolicy = discarded ? .immediate : .after(Date().addingTimeInterval(4))
        await activity.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: policy)
        self.activity = nil
    }

    private func contentState(session: WorkoutSession, currentExercise: String?, rest: RestTimerState?) -> RepSetForgeActivityAttributes.ContentState {
        let allSets = (session.exercises ?? []).flatMap { $0.sets ?? [] }
        let completed = allSets.filter(\.isCompleted)
        let currentExercise = currentExercise ?? session.name
        let matching = (session.exercises ?? []).first { $0.exerciseName == currentExercise }
        let exerciseSets = matching?.sets ?? []
        let currentIndex = min((exerciseSets.first { !$0.isCompleted }?.index ?? exerciseSets.count), max(exerciseSets.count, 1))
        let volume = completed.reduce(0) {
            $0 + TrainingMath.volumeKg(weightKg: $1.weightKg ?? 0, reps: $1.reps ?? 0, kind: $1.type, latestBodyweightKg: nil)
        }
        let phase: RepSetForgeActivityAttributes.ContentState.Phase = rest.map { .resting(end: $0.endDate, total: $0.duration) } ?? .working
        return RepSetForgeActivityAttributes.ContentState(
            currentExerciseName: currentExercise,
            setIndex: currentIndex,
            setTotal: max(exerciseSets.count, 1),
            sessionSetCount: completed.count,
            sessionSetTotal: max(allSets.count, 1),
            phase: phase,
            volumeKg: volume
        )
    }

    private func firstExerciseName(_ session: WorkoutSession) -> String {
        (session.exercises ?? []).sorted { $0.order < $1.order }.first?.exerciseName ?? session.name
    }
}

struct CSVService {
    enum CSVError: LocalizedError, Equatable {
        case missingHeader
        case invalidRow(Int)

        var errorDescription: String? {
            switch self {
            case .missingHeader:
                return "CSV must include date, exercise, set_type, weight_kg, reps, and rpe columns."
            case .invalidRow(let line):
                return "Line \(line) could not be imported."
            }
        }
    }

    struct ImportedSet: Equatable {
        let date: Date
        let exercise: String
        let kind: SetKind
        let weightKg: Double
        let reps: Int
        let rpe: Double?
    }

    struct ImportResult: Equatable {
        let sessionCount: Int
        let setCount: Int
        let createdExerciseCount: Int
        let rebuiltPRCount: Int
    }

    func export(sessions: [WorkoutSession]) -> String {
        var rows = ["date,exercise,set_type,weight_kg,reps,rpe"]
        for session in sessions where session.status == .completed {
            for exercise in session.exercises ?? [] {
                for set in exercise.sets ?? [] where set.isCompleted {
                    rows.append([
                        ISO8601DateFormatter().string(from: set.completedAt ?? session.startedAt),
                        exercise.exerciseName,
                        set.type.rawValue,
                        String(format: "%.2f", set.weightKg ?? 0),
                        "\(set.reps ?? 0)",
                        set.rpe.map { String(format: "%.1f", $0) } ?? ""
                    ].joined(separator: ","))
                }
            }
        }
        return rows.joined(separator: "\n")
    }

    func parseSets(from csv: String) throws -> [ImportedSet] {
        let lines = csv.split(whereSeparator: \.isNewline).map(String.init)
        guard let header = lines.first?.split(separator: ",").map({ $0.trimmingCharacters(in: .whitespaces).lowercased() }),
              header == ["date", "exercise", "set_type", "weight_kg", "reps", "rpe"]
        else { throw CSVError.missingHeader }

        let formatter = ISO8601DateFormatter()
        return try lines.dropFirst().enumerated().map { offset, line in
            let fields = line.split(separator: ",", omittingEmptySubsequences: false).map { String($0).trimmingCharacters(in: .whitespaces) }
            guard fields.count == 6,
                  let date = formatter.date(from: fields[0]),
                  !fields[1].isEmpty,
                  let kind = SetKind(rawValue: fields[2]),
                  let weight = Double(fields[3]),
                  let reps = Int(fields[4])
            else { throw CSVError.invalidRow(offset + 2) }
            return ImportedSet(date: date, exercise: fields[1], kind: kind, weightKg: weight, reps: reps, rpe: Double(fields[5]))
        }
    }

    @MainActor
    func importSets(from csv: String, context: ModelContext) throws -> ImportResult {
        let rows = try parseSets(from: csv).sorted { $0.date < $1.date }
        guard !rows.isEmpty else {
            return ImportResult(sessionCount: 0, setCount: 0, createdExerciseCount: 0, rebuiltPRCount: 0)
        }

        var exercisesByKey = Dictionary(uniqueKeysWithValues: ((try? context.fetch(FetchDescriptor<Exercise>())) ?? []).map { ($0.canonicalNameKey, $0) })
        var createdExercises = 0
        var sessionsCreated = 0

        for group in Dictionary(grouping: rows, by: importSessionKey(for:)).values.sorted(by: { ($0.first?.date ?? .distantPast) < ($1.first?.date ?? .distantPast) }) {
            let session = WorkoutSession(name: "Imported Workout")
            session.startedAt = group.first?.date ?? Date()
            session.endedAt = group.last?.date.addingTimeInterval(60) ?? session.startedAt
            session.status = .completed
            session.exercises = []

            let exerciseGroups = Dictionary(grouping: group, by: { TrainingMath.canonicalNameKey($0.exercise) })
            for (order, exerciseGroup) in exerciseGroups.values.sorted(by: { ($0.first?.date ?? .distantPast) < ($1.first?.date ?? .distantPast) }).enumerated() {
                guard let first = exerciseGroup.first else { continue }
                let key = TrainingMath.canonicalNameKey(first.exercise)
                let exercise: Exercise
                if let existing = exercisesByKey[key] {
                    exercise = existing
                } else {
                    let created = Exercise(name: first.exercise, primary: .chest)
                    context.insert(created)
                    exercisesByKey[key] = created
                    createdExercises += 1
                    exercise = created
                }

                let sessionExercise = SessionExercise(exercise: exercise, order: order, targetSets: 0)
                sessionExercise.sets = exerciseGroup.enumerated().map { index, row in
                    let set = SetEntry(index: index + 1, type: row.kind, weightKg: row.weightKg, reps: row.reps)
                    set.rpe = row.rpe
                    set.completedAt = row.date
                    set.touchedWeight = true
                    set.touchedReps = true
                    return set
                }
                session.exercises?.append(sessionExercise)
            }

            context.insert(session)
            sessionsCreated += 1
        }

        let rebuilt = PRRebuildService().rebuildAll(context: context, bodyweightKg: nil)
        try context.save()
        return ImportResult(sessionCount: sessionsCreated, setCount: rows.count, createdExerciseCount: createdExercises, rebuiltPRCount: rebuilt)
    }

    private func importSessionKey(for row: ImportedSet) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: row.date)
    }
}

struct PRRebuildService {
    @MainActor
    @discardableResult
    func rebuildAll(context: ModelContext, bodyweightKg: Double?) -> Int {
        let existing = (try? context.fetch(FetchDescriptor<PRRecord>())) ?? []
        existing.forEach(context.delete)

        let sessions = ((try? context.fetch(FetchDescriptor<WorkoutSession>())) ?? [])
            .filter { $0.status == .completed }
            .sorted { $0.startedAt < $1.startedAt }

        for session in sessions {
            for exercise in session.exercises ?? [] {
                for set in exercise.sets ?? [] {
                    set.isPR = false
                }
            }
        }

        var bestByExerciseAndKind: [String: Double] = [:]
        var inserted = 0
        for session in sessions {
            for exercise in session.exercises ?? [] {
                let sortedSets = (exercise.sets ?? []).sorted { ($0.completedAt ?? session.startedAt) < ($1.completedAt ?? session.startedAt) }
                for set in sortedSets where set.isCompleted && set.type != .warmup {
                    let weight = set.type == .bodyweight ? (bodyweightKg ?? set.weightKg ?? 0) : (set.weightKg ?? 0)
                    guard let reps = set.reps, reps > 0 else { continue }
                    let values: [(String, Double)] = [
                        ("bestWeight", weight),
                        ("bestVolume", TrainingMath.volumeKg(weightKg: weight, reps: reps, kind: set.type, latestBodyweightKg: bodyweightKg)),
                        ("bestE1RM", TrainingMath.e1RM(weightKg: weight, reps: reps) ?? 0)
                    ].filter { $0.1 > 0 }

                    var setWasPR = false
                    for (kind, value) in values {
                        let key = "\(TrainingMath.canonicalNameKey(exercise.exerciseName))|\(kind)"
                        if value > (bestByExerciseAndKind[key] ?? 0) {
                            bestByExerciseAndKind[key] = value
                            context.insert(PRRecord(exerciseName: exercise.exerciseName, kind: kind, value: value, setID: set.id, achievedAt: set.completedAt ?? session.startedAt))
                            setWasPR = true
                            inserted += 1
                        }
                    }
                    set.isPR = setWasPR
                }
            }
        }
        return inserted
    }
}

@MainActor final class AppStore: ObservableObject {
    @Published var selectedTab: RootTab = .home
    @Published var activeSession: WorkoutSession?
    @Published var minimizedSessionVisible = false
    @Published var restorePrompt: String?
    @Published var lastSummary: WorkoutSession?
    @Published var healthStatusMessage: String?

    let restTimer = RestTimerManager()
    let restorePolicy = RestorePolicy()
    let prService = PRService()
    let progressionService = ProgressionService()
    let healthExporter: HealthExporting
    let liveActivity: LiveActivityCoordinating

    init(healthExporter: HealthExporting = HealthKitWorkoutExporter(), liveActivity: LiveActivityCoordinating = ActivityKitLiveActivityCoordinator()) {
        self.healthExporter = healthExporter
        self.liveActivity = liveActivity
    }

    func restoreIfNeeded(from sessions: [WorkoutSession]) {
        let active = sessions.filter { $0.status == .active }.sorted { $0.startedAt > $1.startedAt }.first
        switch restorePolicy.decision(for: active) {
        case .none:
            activeSession = nil
        case .silentResume:
            activeSession = active
            minimizedSessionVisible = true
        case .needsResolution(let reason):
            activeSession = active
            restorePrompt = reason
        }
    }

    func start(session: WorkoutSession, context: ModelContext) {
        activeSession = session
        minimizedSessionVisible = false
        context.insert(session)
        try? context.save()
        Task { await liveActivity.start(session: session) }
    }

    func complete(set: SetEntry, in exercise: SessionExercise, context: ModelContext, bodyweightKg: Double?) {
        guard !set.isCompleted else { return }
        if set.weightKg == nil { set.weightKg = inheritedWeight(for: set, in: exercise) ?? 0 }
        if set.reps == nil { set.reps = inheritedReps(for: set, in: exercise) ?? 8 }
        set.completedAt = Date()
        exercise.chartCollapsed = true

        let records = (try? context.fetch(FetchDescriptor<PRRecord>())) ?? []
        let prs = prService.evaluate(set: set, exerciseName: exercise.exerciseName, existing: records, latestBodyweightKg: bodyweightKg)
        if !prs.isEmpty {
            set.isPR = true
            prs.forEach { context.insert(PRRecord(exerciseName: exercise.exerciseName, kind: $0.kind, value: $0.value, setID: set.id, achievedAt: set.completedAt ?? Date())) }
        }
        if let sets = exercise.sets, set.id == sets.sorted(by: { $0.index < $1.index }).last?.id {
            exercise.sets?.append(SetEntry(index: sets.count + 1, weightKg: set.weightKg, reps: set.reps, restSeconds: set.restSeconds))
        }
        restTimer.start(duration: TimeInterval(set.restSeconds))
        try? context.save()
        if let session = activeSession {
            Task { await liveActivity.update(session: session, currentExercise: exercise.exerciseName, rest: restTimer.state) }
        }
    }

    func inheritedWeight(for set: SetEntry, in exercise: SessionExercise) -> Double? {
        let sorted = (exercise.sets ?? []).sorted { $0.index < $1.index }
        guard let idx = sorted.firstIndex(where: { $0.id == set.id }) else { return set.weightKg }
        return set.weightKg ?? sorted[..<idx].last(where: { $0.weightKg != nil })?.weightKg
    }

    func inheritedReps(for set: SetEntry, in exercise: SessionExercise) -> Int? {
        let sorted = (exercise.sets ?? []).sorted { $0.index < $1.index }
        guard let idx = sorted.firstIndex(where: { $0.id == set.id }) else { return set.reps }
        return set.reps ?? sorted[..<idx].last(where: { $0.reps != nil })?.reps
    }

    func finishActiveSession(context: ModelContext, bodyweightKg: Double?) {
        guard let session = activeSession else { return }
        session.status = .completed
        session.endedAt = Date()
        try? context.save()
        lastSummary = session
        activeSession = nil
        minimizedSessionVisible = false
        Task {
            let authorized = await healthExporter.requestAuthorizationIfNeeded()
            if authorized, let uuid = try? await healthExporter.saveWorkout(session, bodyweightKg: bodyweightKg) {
                await MainActor.run {
                    session.healthKitUUID = uuid
                    healthStatusMessage = "Saved to Apple Health"
                    try? context.save()
                }
            } else {
                await MainActor.run { healthStatusMessage = "Health access off — enable in Settings › Health" }
            }
            await liveActivity.end(session: session, discarded: false)
        }
    }

    func persistHistoricalChange(session: WorkoutSession, context: ModelContext, bodyweightKg: Double?) {
        session.updatedAt = Date()
        _ = PRRebuildService().rebuildAll(context: context, bodyweightKg: bodyweightKg)
        try? context.save()

        guard session.status == .completed, session.healthKitUUID != nil else { return }
        Task {
            if let uuid = try? await healthExporter.saveWorkout(session, bodyweightKg: bodyweightKg) {
                await MainActor.run {
                    session.healthKitUUID = uuid
                    healthStatusMessage = "Updated Apple Health export"
                    try? context.save()
                }
            }
        }
    }

    func deleteHistoricalSession(_ session: WorkoutSession, context: ModelContext, bodyweightKg: Double?) {
        let healthUUID = session.healthKitUUID
        context.delete(session)
        _ = PRRebuildService().rebuildAll(context: context, bodyweightKg: bodyweightKg)
        try? context.save()

        guard let healthUUID else { return }
        Task {
            try? await healthExporter.deleteWorkout(uuid: healthUUID)
            await MainActor.run { healthStatusMessage = "Removed Apple Health export" }
        }
    }
}

enum RootTab: String, CaseIterable, Identifiable {
    case home, history, progress, library
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var icon: String {
        switch self {
        case .home: "house"
        case .history: "calendar"
        case .progress: "chart.line.uptrend.xyaxis"
        case .library: "books.vertical"
        }
    }
}
