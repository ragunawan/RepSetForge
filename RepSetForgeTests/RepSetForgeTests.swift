import XCTest
import SwiftData
@testable import RepSetForge

final class RepSetForgeTests: XCTestCase {
    func testCanonicalNameDedupStripsPunctuationAndWhitespace() {
        XCTAssertEqual(TrainingMath.canonicalNameKey(" Bench-Press!! "), "benchpress")
        XCTAssertTrue(TrainingMath.namesAreSimilar("Bench Press", "bench press"))
        XCTAssertTrue(TrainingMath.namesAreSimilar("Bench Pres", "Bench Press"))
    }

    func testEpleyOneRepMaxCapsAtTwelveReps() {
        XCTAssertEqual(TrainingMath.e1RM(weightKg: 100, reps: 10)!, 133.333, accuracy: 0.01)
        XCTAssertNil(TrainingMath.e1RM(weightKg: 100, reps: 13))
    }

    func testWarmupsExcludedFromVolume() {
        XCTAssertEqual(TrainingMath.volumeKg(weightKg: 100, reps: 8, kind: .warmup, latestBodyweightKg: nil), 0)
        XCTAssertEqual(TrainingMath.volumeKg(weightKg: 100, reps: 8, kind: .working, latestBodyweightKg: nil), 800)
    }

    func testRestTimerUsesWallClockMath() {
        let start = Date(timeIntervalSince1970: 100)
        let rest = RestTimerState(startedAt: start, duration: 90)
        XCTAssertEqual(rest.remaining(at: Date(timeIntervalSince1970: 130)), 60)
        XCTAssertEqual(rest.overtime(at: Date(timeIntervalSince1970: 200)), 10)
    }

    @MainActor
    func testRestTimerReschedulesNotificationsWhenExtended() async {
        let scheduler = SpyRestNotificationScheduler()
        let manager = RestTimerManager(scheduler: scheduler)
        manager.start(duration: 60, now: Date())
        await Task.yield()
        manager.extend(seconds: 30)
        await Task.yield()

        XCTAssertEqual(scheduler.scheduledDurations.count, 2)
        XCTAssertEqual(scheduler.scheduledDurations.first, 60)
        XCTAssertEqual(scheduler.scheduledDurations.last ?? 0, 90, accuracy: 1)
    }

    func testRestorePolicy() {
        let recent = WorkoutSession(name: "Recent")
        recent.startedAt = Date(timeIntervalSince1970: 1000)
        XCTAssertEqual(RestorePolicy().decision(for: recent, now: Date(timeIntervalSince1970: 1000 + 60)), .silentResume)

        let stale = WorkoutSession(name: "Stale")
        stale.startedAt = Date(timeIntervalSince1970: 1000)
        if case .needsResolution = RestorePolicy().decision(for: stale, now: Date(timeIntervalSince1970: 1000 + 5 * 60 * 60)) {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected stale session resolution")
        }
    }

    func testProgressionLadderMarksCurrentLevel() {
        let rule = ProgressionRule(repRangeLow: 8, repRangeHigh: 10)
        let completed = SetEntry(index: 1, weightKg: 100, reps: 8)
        completed.rpe = 8
        completed.completedAt = Date()
        let ladder = ProgressionService().ladder(rule: rule, baseWeightKg: 100, qualifyingSets: [completed])
        XCTAssertTrue(ladder[0].completed)
        XCTAssertTrue(ladder[1].current)
    }

    func testFiveThreeOnePrescriptionsUseTrainingMax() {
        let rule = ProgressionRule(type: .fiveThreeOne)
        rule.trainingMaxKg = 100
        rule.incrementKg = 2.5
        let prescriptions = ProgressionService().prescriptions(rule: rule, baseWeightKg: 80, recentSets: [])
        XCTAssertEqual(prescriptions.count, 9)
        XCTAssertEqual(prescriptions[0].targetWeightKg, 65)
        XCTAssertEqual(prescriptions[2].targetReps, 5)
        XCTAssertTrue(prescriptions[2].title.contains("+"))
    }

    func testRIRAutoregulationAdjustsFromLastSet() {
        let rule = ProgressionRule(type: .rirAutoregulation)
        rule.targetRIR = 2
        rule.rirLoadAdjustmentKg = 2.5
        let easySet = SetEntry(index: 1, weightKg: 100, reps: 8)
        easySet.rpe = 7
        easySet.completedAt = Date()
        let prescription = ProgressionService().prescriptions(rule: rule, baseWeightKg: 100, recentSets: [easySet]).first
        XCTAssertEqual(prescription?.targetWeightKg, 102.5)
        XCTAssertEqual(prescription?.targetRPE, 8)
    }

    func testWatchTelemetryHidesWhenStale() {
        let fresh = WorkoutTelemetrySnapshot(heartRateBPM: 118, activeEnergyKCal: 328, receivedAt: Date(timeIntervalSince1970: 10))
        XCTAssertTrue(fresh.visible(at: Date(timeIntervalSince1970: 14)))
        XCTAssertFalse(fresh.visible(at: Date(timeIntervalSince1970: 16)))
    }

    func testCSVExportHeaderAndRows() {
        let exercise = Exercise(name: "Bench Press", primary: .chest)
        let sessionExercise = SessionExercise(exercise: exercise, order: 0, targetSets: 1)
        let set = sessionExercise.sets!.first!
        set.weightKg = 100
        set.reps = 8
        set.completedAt = Date(timeIntervalSince1970: 10)
        let session = WorkoutSession(name: "Push", exercises: [sessionExercise])
        session.status = .completed
        let csv = CSVService().export(sessions: [session])
        XCTAssertTrue(csv.contains("date,exercise,set_type,weight_kg,reps,rpe"))
        XCTAssertTrue(csv.contains("Bench Press"))
    }

    func testCSVImportParsesRowsAndReportsInvalidHeaders() throws {
        let csv = """
        date,exercise,set_type,weight_kg,reps,rpe
        1970-01-01T00:00:10Z,Bench Press,working,100,8,8.5
        """
        let rows = try CSVService().parseSets(from: csv)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].exercise, "Bench Press")
        XCTAssertEqual(rows[0].kind, .working)
        XCTAssertEqual(rows[0].weightKg, 100)
        XCTAssertEqual(rows[0].reps, 8)
        XCTAssertEqual(rows[0].rpe, 8.5)

        XCTAssertThrowsError(try CSVService().parseSets(from: "bad,header"))
    }

    @MainActor
    func testCSVImportCreatesCompletedSessionsExercisesAndPRs() throws {
        let container = PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        let csv = """
        date,exercise,set_type,weight_kg,reps,rpe
        1970-01-01T00:00:10Z,Bench Press,working,100,8,8.5
        1970-01-01T00:02:10Z,Bench Press,working,105,6,9
        1970-01-02T00:00:10Z,Cable Row,working,70,10,8
        """

        let result = try CSVService().importSets(from: csv, context: context)

        XCTAssertEqual(result.sessionCount, 2)
        XCTAssertEqual(result.setCount, 3)
        XCTAssertEqual(result.createdExerciseCount, 2)
        let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
        XCTAssertEqual(sessions.filter { $0.status == .completed }.count, 2)
        XCTAssertEqual(sessions.reduce(0) { $0 + $1.completedSetCount }, 3)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Exercise>()), 2)
        XCTAssertGreaterThan(try context.fetchCount(FetchDescriptor<PRRecord>()), 0)
    }

    @MainActor
    func testPRRebuildClearsHistoricalRecordsWhenSetIsEditedLower() throws {
        let container = PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        let exercise = Exercise(name: "Bench Press", primary: .chest)
        let sessionExercise = SessionExercise(exercise: exercise, order: 0, targetSets: 1)
        let set = sessionExercise.sets!.first!
        set.weightKg = 120
        set.reps = 5
        set.completedAt = Date(timeIntervalSince1970: 10)
        let session = WorkoutSession(name: "Imported", exercises: [sessionExercise])
        session.startedAt = Date(timeIntervalSince1970: 0)
        session.endedAt = Date(timeIntervalSince1970: 600)
        session.status = .completed
        context.insert(exercise)
        context.insert(session)

        XCTAssertEqual(PRRebuildService().rebuildAll(context: context, bodyweightKg: nil), 3)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<PRRecord>()), 3)

        set.weightKg = 0
        set.reps = 0
        XCTAssertEqual(PRRebuildService().rebuildAll(context: context, bodyweightKg: nil), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<PRRecord>()), 0)
        XCTAssertFalse(set.isPR)
    }

    @MainActor
    func testHistoricalChangeRebuildsPRsAndRewritesExistingHealthWorkout() async throws {
        let container = PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        let exporter = SpyHealthExporter()
        let store = AppStore(healthExporter: exporter, liveActivity: NoopLiveActivityCoordinator())
        let exercise = Exercise(name: "Bench Press", primary: .chest)
        let sessionExercise = SessionExercise(exercise: exercise, order: 0, targetSets: 1)
        let set = sessionExercise.sets!.first!
        set.weightKg = 100
        set.reps = 8
        set.completedAt = Date(timeIntervalSince1970: 10)
        let session = WorkoutSession(name: "Historical", exercises: [sessionExercise])
        session.status = .completed
        session.healthKitUUID = UUID()
        context.insert(exercise)
        context.insert(session)

        store.persistHistoricalChange(session: session, context: context, bodyweightKg: nil)
        await waitFor { exporter.savedSessionIDs.count == 1 }

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<PRRecord>()), 3)
        XCTAssertEqual(exporter.savedSessionIDs, [session.id])
    }

    @MainActor
    func testDeletingHistoricalSessionRebuildsPRsAndDeletesHealthWorkout() async throws {
        let container = PersistenceController.makeContainer(inMemory: true)
        let context = container.mainContext
        let exporter = SpyHealthExporter()
        let store = AppStore(healthExporter: exporter, liveActivity: NoopLiveActivityCoordinator())
        let healthID = UUID()
        let exercise = Exercise(name: "Bench Press", primary: .chest)
        let session = WorkoutSession(name: "Historical", exercises: [SessionExercise(exercise: exercise, order: 0, targetSets: 1)])
        session.status = .completed
        session.healthKitUUID = healthID
        context.insert(exercise)
        context.insert(session)

        store.deleteHistoricalSession(session, context: context, bodyweightKg: nil)
        await waitFor { exporter.deletedUUIDs.count == 1 }

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WorkoutSession>()), 0)
        XCTAssertEqual(exporter.deletedUUIDs, [healthID])
    }

    @MainActor
    private func waitFor(_ predicate: @escaping @MainActor () -> Bool) async {
        for _ in 0..<50 {
            if predicate() { return }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }
}

@MainActor
private final class SpyRestNotificationScheduler: RestNotificationScheduling {
    var scheduledDurations: [TimeInterval] = []
    var cancelCount = 0

    func scheduleRestComplete(after seconds: TimeInterval) async {
        scheduledDurations.append(seconds)
    }

    func cancelRestComplete() async {
        cancelCount += 1
    }
}

@MainActor
private final class SpyHealthExporter: HealthExporting {
    var savedSessionIDs: [UUID] = []
    var deletedUUIDs: [UUID] = []

    func requestAuthorizationIfNeeded() async -> Bool {
        true
    }

    func saveWorkout(_ session: WorkoutSession, bodyweightKg: Double?) async throws -> UUID {
        savedSessionIDs.append(session.id)
        return session.healthKitUUID ?? UUID()
    }

    func deleteWorkout(uuid: UUID) async throws {
        deletedUUIDs.append(uuid)
    }
}
