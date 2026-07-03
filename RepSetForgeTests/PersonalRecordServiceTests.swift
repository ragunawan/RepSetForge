import XCTest
import SwiftData
@testable import RepSetForge

final class PersonalRecordServiceTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUpWithError() throws {
        let schema = Schema([Quest.self, Exercise.self, ExerciseSet.self, PersonalRecord.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
    }

    func testStrengthSetCreatesMaxWeightMaxRepsAndBestVolumeRecords() {
        let bench = Exercise(name: "Bench Press", primaryMuscle: .chest, exerciseType: .strength)
        bench.sets = [ExerciseSet(setNumber: 1, reps: 5, weight: 185, completed: true)]

        let updates = PersonalRecordService.evaluateRecords(for: [bench], context: context)

        XCTAssertEqual(updates.count, 3)
        let records = (try? context.fetch(FetchDescriptor<PersonalRecord>())) ?? []
        XCTAssertEqual(records.first { $0.recordType == .maxWeight }?.value, 185)
        XCTAssertEqual(records.first { $0.recordType == .maxReps }?.value, 5)
        XCTAssertEqual(records.first { $0.recordType == .bestVolume }?.value, 925)
    }

    func testOnlyImprovedValuesUpdateExistingRecord() {
        let bench = Exercise(name: "Bench Press", primaryMuscle: .chest, exerciseType: .strength)
        bench.sets = [ExerciseSet(setNumber: 1, reps: 5, weight: 185, completed: true)]
        PersonalRecordService.evaluateRecords(for: [bench], context: context)

        let weaker = Exercise(name: "Bench Press", primaryMuscle: .chest, exerciseType: .strength)
        weaker.sets = [ExerciseSet(setNumber: 1, reps: 5, weight: 135, completed: true)]
        let updates = PersonalRecordService.evaluateRecords(for: [weaker], context: context)

        XCTAssertTrue(updates.isEmpty)
        let records = (try? context.fetch(FetchDescriptor<PersonalRecord>())) ?? []
        XCTAssertEqual(records.first { $0.recordType == .maxWeight }?.value, 185)
    }

    func testCrossUnitComparisonConvertsBeforeDeciding() {
        let bench = Exercise(name: "Bench Press", primaryMuscle: .chest, exerciseType: .strength)
        bench.sets = [ExerciseSet(setNumber: 1, reps: 5, weight: 185, completed: true)] // pounds
        PersonalRecordService.evaluateRecords(for: [bench], context: context)

        // 80 kg (~176 lb) is weaker than the existing 185 lb record — should not improve it.
        let weakerKg = Exercise(name: "Bench Press", primaryMuscle: .chest, exerciseType: .strength)
        weakerKg.sets = [ExerciseSet(setNumber: 1, reps: 5, weight: 80, completed: true, weightUnit: .kilograms)]
        let noImprovement = PersonalRecordService.evaluateRecords(for: [weakerKg], context: context)
        XCTAssertTrue(noImprovement.isEmpty)

        // 90 kg (~198 lb) is genuinely heavier — should improve maxWeight and
        // bestVolume (reps tie at 5, so maxReps doesn't count as an improvement).
        // The record now switches to displaying in kilograms, matching how it
        // was actually logged.
        let strongerKg = Exercise(name: "Bench Press", primaryMuscle: .chest, exerciseType: .strength)
        strongerKg.sets = [ExerciseSet(setNumber: 1, reps: 5, weight: 90, completed: true, weightUnit: .kilograms)]
        let improved = PersonalRecordService.evaluateRecords(for: [strongerKg], context: context)
        XCTAssertEqual(Set(improved.map(\.recordType)), [.maxWeight, .bestVolume])

        let records = (try? context.fetch(FetchDescriptor<PersonalRecord>())) ?? []
        let maxWeightRecord = records.first { $0.recordType == .maxWeight }
        XCTAssertEqual(maxWeightRecord?.value, 90)
        XCTAssertEqual(maxWeightRecord?.weightUnit, .kilograms)
    }

    func testBodyweightAndAssistedOnlyTrackMaxReps() {
        let pullUps = Exercise(name: "Pull-Ups", primaryMuscle: .back, exerciseType: .bodyweight)
        pullUps.sets = [ExerciseSet(setNumber: 1, reps: 12, completed: true)]

        let updates = PersonalRecordService.evaluateRecords(for: [pullUps], context: context)

        XCTAssertEqual(updates.count, 1)
        XCTAssertEqual(updates[0].recordType, .maxReps)
    }

    func testDurationExerciseTracksLongestDuration() {
        let plank = Exercise(name: "Plank", primaryMuscle: .core, exerciseType: .duration)
        plank.sets = [ExerciseSet(setNumber: 1, completed: true, durationSeconds: 90)]

        let updates = PersonalRecordService.evaluateRecords(for: [plank], context: context)

        XCTAssertEqual(updates.count, 1)
        XCTAssertEqual(updates[0].recordType, .longestDuration)
        XCTAssertEqual(updates[0].newValue, 90)
    }

    func testCardioTracksFastestPaceAndLowerIsBetter() {
        let run = Exercise(name: "5K Run", primaryMuscle: .cardio, exerciseType: .cardio)
        run.sets = [ExerciseSet(setNumber: 1, completed: true, distanceMiles: 5, durationSeconds: 2400)] // 8 min/mi
        PersonalRecordService.evaluateRecords(for: [run], context: context)

        let faster = Exercise(name: "5K Run", primaryMuscle: .cardio, exerciseType: .cardio)
        faster.sets = [ExerciseSet(setNumber: 1, completed: true, distanceMiles: 5, durationSeconds: 2100)] // 7 min/mi
        let updates = PersonalRecordService.evaluateRecords(for: [faster], context: context)

        XCTAssertEqual(updates.count, 1)
        XCTAssertEqual(updates[0].recordType, .fastestPace)
        let record = (try? context.fetch(FetchDescriptor<PersonalRecord>()))?.first { $0.recordType == .fastestPace }
        XCTAssertEqual(record?.value, 7)
    }

    func testDistanceOnlyExerciseYieldsNoRecordsYet() {
        let walk = Exercise(name: "Walk", primaryMuscle: .cardio, exerciseType: .distance)
        walk.sets = [ExerciseSet(setNumber: 1, completed: true, distanceMiles: 3)]

        let updates = PersonalRecordService.evaluateRecords(for: [walk], context: context)

        XCTAssertTrue(updates.isEmpty)
    }

    func testIncompleteSetsAreIgnored() {
        let bench = Exercise(name: "Bench Press", primaryMuscle: .chest, exerciseType: .strength)
        bench.sets = [ExerciseSet(setNumber: 1, reps: 5, weight: 185, completed: false)]

        let updates = PersonalRecordService.evaluateRecords(for: [bench], context: context)

        XCTAssertTrue(updates.isEmpty)
    }

    func testRebuildAllRecomputesFromCompletedQuestsOnly() {
        let quest = Quest(name: "Push Day", status: .completed)
        quest.completedDate = .now
        let bench = Exercise(name: "Bench Press", primaryMuscle: .chest, exerciseType: .strength)
        bench.sets = [ExerciseSet(setNumber: 1, reps: 5, weight: 185, completed: true)]
        quest.exercises = [bench]
        context.insert(quest)

        let planned = Quest(name: "Planned", status: .planned)
        let squat = Exercise(name: "Squat", primaryMuscle: .legs, exerciseType: .strength)
        squat.sets = [ExerciseSet(setNumber: 1, reps: 5, weight: 300, completed: true)]
        planned.exercises = [squat]
        context.insert(planned)

        try? context.save()

        PersonalRecordService.rebuildAll(context: context)

        let records = (try? context.fetch(FetchDescriptor<PersonalRecord>())) ?? []
        XCTAssertTrue(records.contains { $0.exerciseName == "Bench Press" })
        XCTAssertFalse(records.contains { $0.exerciseName == "Squat" })
    }

    func testRebuildAllIsIdempotentAndDoesNotDuplicate() {
        let quest = Quest(name: "Push Day", status: .completed)
        quest.completedDate = .now
        let bench = Exercise(name: "Bench Press", primaryMuscle: .chest, exerciseType: .strength)
        bench.sets = [ExerciseSet(setNumber: 1, reps: 5, weight: 185, completed: true)]
        quest.exercises = [bench]
        context.insert(quest)
        try? context.save()

        PersonalRecordService.rebuildAll(context: context)
        PersonalRecordService.rebuildAll(context: context)

        let records = (try? context.fetch(FetchDescriptor<PersonalRecord>())) ?? []
        XCTAssertEqual(records.filter { $0.exerciseName == "Bench Press" && $0.recordType == .maxWeight }.count, 1)
    }
}
