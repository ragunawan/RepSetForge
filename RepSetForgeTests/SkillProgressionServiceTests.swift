import XCTest
import SwiftData
@testable import RepSetForge

final class SkillProgressionServiceTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUpWithError() throws {
        let schema = Schema([SkillProgress.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
        SkillProgressionService.seedIfNeeded(context: context)
        try context.save()
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
    }

    private func progress(_ skillID: String) -> SkillProgress? {
        (try? context.fetch(FetchDescriptor<SkillProgress>()))?.first { $0.skillID == skillID }
    }

    func testSeedIfNeededCreatesOneRowPerCatalogSkill() {
        let records = (try? context.fetch(FetchDescriptor<SkillProgress>())) ?? []
        XCTAssertEqual(records.count, RPGSkillRegistry.all.count)
        XCTAssertTrue(records.allSatisfy { !$0.unlocked })
    }

    func testSeedIfNeededIsIdempotent() {
        SkillProgressionService.seedIfNeeded(context: context)
        let records = (try? context.fetch(FetchDescriptor<SkillProgress>())) ?? []
        XCTAssertEqual(records.count, RPGSkillRegistry.all.count)
    }

    func testPrimaryMuscleGrantsFullXPToRelatedSkill() {
        // Power Strike relates to chest+arms. Bench press (chest primary) exercise XP flows in fully.
        let bench = Exercise(name: "Bench Press", primaryMuscle: .chest)
        bench.sets = [ExerciseSet(setNumber: 1, reps: 5, weight: 185, completed: true)]
        let expectedXP = ProgressionService.exerciseXP(bench)

        SkillProgressionService.distributeSkillXP(exercises: [bench], context: context)

        XCTAssertEqual(progress("power_strike")?.totalXP, expectedXP)
    }

    func testSecondaryMuscleGrantsFortyPercentToRelatedSkill() {
        // Quick Shot relates to arms+legs. Exercise primary=chest, secondary=arms -> 40% flows to Quick Shot via arms.
        let bench = Exercise(name: "Bench Press", primaryMuscle: .chest, secondaryMuscles: [.arms])
        bench.sets = [ExerciseSet(setNumber: 1, reps: 5, weight: 185, completed: true)]
        let exerciseXP = ProgressionService.exerciseXP(bench)
        let expectedSecondaryXP = Int((Double(exerciseXP) * 0.4).rounded())

        SkillProgressionService.distributeSkillXP(exercises: [bench], context: context)

        XCTAssertEqual(progress("quick_shot")?.totalXP, expectedSecondaryXP)
        // power_strike relates to both chest (primary, 100%) and arms (secondary, 40%) for this exercise.
        XCTAssertEqual(progress("power_strike")?.totalXP, exerciseXP + expectedSecondaryXP)
    }

    func testPersonalRecordGrantsFlatBonusToPrimaryMuscleSkills() {
        let bench = Exercise(name: "Bench Press", primaryMuscle: .chest)
        bench.sets = [ExerciseSet(setNumber: 1, reps: 5, weight: 185, completed: true)]
        let exerciseXP = ProgressionService.exerciseXP(bench)

        SkillProgressionService.distributeSkillXP(exercises: [bench], prExerciseNames: ["Bench Press"], context: context)

        XCTAssertEqual(progress("power_strike")?.totalXP, exerciseXP + SkillProgressionService.personalRecordSkillXPBonus)
    }

    func testSkillUnlocksWhenThresholdCrossedAndReturnsUnlockEvent() {
        let skill = try! XCTUnwrap(RPGSkillRegistry.skill(id: "power_strike"))
        let bigBench = Exercise(name: "Bench Press", primaryMuscle: .chest)
        bigBench.sets = [ExerciseSet(setNumber: 1, reps: 100, weight: 1000, completed: true)] // huge XP, crosses threshold

        let unlocked = SkillProgressionService.distributeSkillXP(exercises: [bigBench], context: context)

        XCTAssertTrue(unlocked.contains { $0.skillID == "power_strike" })
        let record = try! XCTUnwrap(progress("power_strike"))
        XCTAssertTrue(record.unlocked)
        XCTAssertNotNil(record.unlockedDate)
        XCTAssertGreaterThanOrEqual(record.totalXP, skill.unlockThresholdXP)
    }

    func testUnlockedSkillIDsReflectsOnlyUnlockedRecords() {
        let bigBench = Exercise(name: "Bench Press", primaryMuscle: .chest)
        bigBench.sets = [ExerciseSet(setNumber: 1, reps: 100, weight: 1000, completed: true)]
        SkillProgressionService.distributeSkillXP(exercises: [bigBench], context: context)

        let unlockedIDs = SkillProgressionService.unlockedSkillIDs(context: context)

        XCTAssertTrue(unlockedIDs.contains("power_strike"))
        XCTAssertFalse(unlockedIDs.contains("firebolt"))
    }

    func testUnrelatedMuscleGrantsNoXP() {
        let squat = Exercise(name: "Squat", primaryMuscle: .legs)
        squat.sets = [ExerciseSet(setNumber: 1, reps: 5, weight: 300, completed: true)]

        SkillProgressionService.distributeSkillXP(exercises: [squat], context: context)

        XCTAssertEqual(progress("firebolt")?.totalXP, 0) // firebolt relates to shoulders/arms only
    }
}
