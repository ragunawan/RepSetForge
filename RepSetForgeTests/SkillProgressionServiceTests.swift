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

    // MARK: equip / auto-equip

    func testFirstSkillUnlockedInACategoryIsAutoEquipped() {
        // power_strike (category .attack) is the only attack skill chest feeds.
        let bigBench = Exercise(name: "Bench Press", primaryMuscle: .chest)
        bigBench.sets = [ExerciseSet(setNumber: 1, reps: 100, weight: 1000, completed: true)]

        SkillProgressionService.distributeSkillXP(exercises: [bigBench], context: context)

        let record = try! XCTUnwrap(progress("power_strike"))
        XCTAssertTrue(record.equipped)
        XCTAssertTrue(SkillProgressionService.equippedSkillIDs(context: context).contains("power_strike"))
    }

    func testAutoEquipDoesNotOverrideAnAlreadyEquippedSkillInCategory() {
        // Manually equip shadow_dash (also .attack) first, as if the player chose it earlier.
        let shadowDash = try! XCTUnwrap(progress("shadow_dash"))
        shadowDash.unlocked = true
        shadowDash.equipped = true

        let bigBench = Exercise(name: "Bench Press", primaryMuscle: .chest)
        bigBench.sets = [ExerciseSet(setNumber: 1, reps: 100, weight: 1000, completed: true)]
        SkillProgressionService.distributeSkillXP(exercises: [bigBench], context: context)

        // power_strike unlocked, but shadow_dash was already the category's choice.
        XCTAssertTrue(try! XCTUnwrap(progress("power_strike")).unlocked)
        XCTAssertFalse(try! XCTUnwrap(progress("power_strike")).equipped)
        XCTAssertTrue(try! XCTUnwrap(progress("shadow_dash")).equipped)
    }

    func testEquipSwapsWithinCategoryAndLeavesOtherCategoriesAlone() {
        let powerStrike = try! XCTUnwrap(progress("power_strike")) // attack
        powerStrike.unlocked = true
        powerStrike.equipped = true
        let shadowDash = try! XCTUnwrap(progress("shadow_dash")) // attack
        shadowDash.unlocked = true
        let ironGuard = try! XCTUnwrap(progress("iron_guard")) // defense
        ironGuard.unlocked = true
        ironGuard.equipped = true

        SkillProgressionService.equip("shadow_dash", context: context)

        XCTAssertFalse(try! XCTUnwrap(progress("power_strike")).equipped)
        XCTAssertTrue(try! XCTUnwrap(progress("shadow_dash")).equipped)
        XCTAssertTrue(try! XCTUnwrap(progress("iron_guard")).equipped) // untouched, different category
    }

    func testEquipLockedSkillIsANoOp() {
        SkillProgressionService.equip("power_strike", context: context) // never unlocked

        XCTAssertFalse(try! XCTUnwrap(progress("power_strike")).equipped)
    }

    func testEquippedSkillIDsRequiresBothUnlockedAndEquipped() {
        let record = try! XCTUnwrap(progress("power_strike"))
        record.equipped = true // equipped flag set but not unlocked (shouldn't normally happen, but verify the guard)

        XCTAssertFalse(SkillProgressionService.equippedSkillIDs(context: context).contains("power_strike"))
    }
}
