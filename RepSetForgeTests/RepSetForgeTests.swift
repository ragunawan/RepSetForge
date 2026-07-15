import XCTest
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
}
