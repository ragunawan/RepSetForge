import XCTest
import SwiftData
@testable import SetCraft

@MainActor
final class RPGBossMilestoneTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(schema: PersistenceController.schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: PersistenceController.schema, configurations: [config])
        return ModelContext(container)
    }

    // MARK: Activation

    func testNoBossBeforeMilestoneLevel() {
        let state = RPGEncounterState()
        let snapshot = RPGProgressionSnapshot(currentLevel: 9)
        XCTAssertNil(BossMilestoneService.activateBossIfNeeded(state: state, snapshot: snapshot))
        XCTAssertNil(state.activeBossID)
    }

    func testBossActivatesAtMilestoneLevel() {
        let state = RPGEncounterState()
        let snapshot = RPGProgressionSnapshot(currentLevel: 10)
        let boss = BossMilestoneService.activateBossIfNeeded(state: state, snapshot: snapshot)
        XCTAssertEqual(boss?.id, "iron_goblin_captain")
        XCTAssertEqual(state.activeBossID, "iron_goblin_captain")
        XCTAssertEqual(state.activeMilestoneQuestID, "milestone_first_5_workouts")
    }

    func testSkippedBossesActivateInOrder() {
        // A player who reached level 25 without fighting bosses faces the level-10 boss first.
        let state = RPGEncounterState()
        let snapshot = RPGProgressionSnapshot(currentLevel: 25)
        XCTAssertEqual(BossMilestoneService.activateBossIfNeeded(state: state, snapshot: snapshot)?.id, "iron_goblin_captain")
    }

    func testActivationIsIdempotentWhileBossActive() {
        let state = RPGEncounterState()
        let snapshot = RPGProgressionSnapshot(currentLevel: 20)
        BossMilestoneService.activateBossIfNeeded(state: state, snapshot: snapshot)
        XCTAssertNil(
            BossMilestoneService.activateBossIfNeeded(state: state, snapshot: snapshot),
            "A second activation must not replace the active boss"
        )
        XCTAssertEqual(state.activeBossID, "iron_goblin_captain")
    }

    // MARK: Defeat via milestone quest

    func testBossNotDefeatedUntilMilestoneQuestSatisfied() {
        let state = RPGEncounterState(
            activeBossID: "iron_goblin_captain",
            activeMilestoneQuestID: "milestone_first_5_workouts"
        )
        let before = RPGProgressionSnapshot(currentLevel: 10, completedWorkoutCount: 4)
        XCTAssertFalse(BossMilestoneService.isActiveBossDefeated(state: state, snapshot: before))

        let after = RPGProgressionSnapshot(currentLevel: 10, completedWorkoutCount: 5)
        XCTAssertTrue(BossMilestoneService.isActiveBossDefeated(state: state, snapshot: after))
    }

    func testStreakMilestoneDefeatsSecondBoss() {
        let state = RPGEncounterState(
            activeBossID: "bone_colossus",
            activeMilestoneQuestID: "milestone_7_day_streak"
        )
        XCTAssertFalse(BossMilestoneService.isActiveBossDefeated(
            state: state,
            snapshot: RPGProgressionSnapshot(currentLevel: 20, currentWorkoutStreak: 6)
        ))
        XCTAssertTrue(BossMilestoneService.isActiveBossDefeated(
            state: state,
            snapshot: RPGProgressionSnapshot(currentLevel: 20, currentWorkoutStreak: 7)
        ))
    }

    func testCompleteActiveBossRecordsAndClears() {
        let state = RPGEncounterState(
            activeBossID: "iron_goblin_captain",
            activeMilestoneQuestID: "milestone_first_5_workouts"
        )
        BossMilestoneService.completeActiveBoss(state: state)

        XCTAssertNil(state.activeBossID)
        XCTAssertNil(state.activeMilestoneQuestID)
        XCTAssertEqual(state.completedBossIDs, ["iron_goblin_captain"])
        XCTAssertEqual(state.completedMilestoneQuestIDs, ["milestone_first_5_workouts"])
        XCTAssertEqual(state.lastDefeatedBossID, "iron_goblin_captain")
        XCTAssertNotNil(state.lastBossDefeatDate)
    }

    func testCompletedBossDoesNotImmediatelyReappear() {
        let state = RPGEncounterState(
            activeBossID: "iron_goblin_captain",
            activeMilestoneQuestID: "milestone_first_5_workouts"
        )
        BossMilestoneService.completeActiveBoss(state: state)

        // Still level 10: no boss should reactivate until level 20.
        let snapshot = RPGProgressionSnapshot(currentLevel: 10, completedWorkoutCount: 5)
        XCTAssertNil(BossMilestoneService.activateBossIfNeeded(state: state, snapshot: snapshot))

        // At level 20 the next boss awakens, not the defeated one.
        let leveled = RPGProgressionSnapshot(currentLevel: 20, completedWorkoutCount: 5)
        XCTAssertEqual(BossMilestoneService.activateBossIfNeeded(state: state, snapshot: leveled)?.id, "bone_colossus")
    }

    // MARK: Persistence

    func testBossStatePersistsAcrossContexts() throws {
        let config = ModelConfiguration(schema: PersistenceController.schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: PersistenceController.schema, configurations: [config])

        let writeContext = ModelContext(container)
        let state = RPGEncounterState()
        writeContext.insert(state)
        BossMilestoneService.activateBossIfNeeded(state: state, snapshot: RPGProgressionSnapshot(currentLevel: 10))
        try writeContext.save()

        let readContext = ModelContext(container)
        let fetched = try readContext.fetch(FetchDescriptor<RPGEncounterState>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.activeBossID, "iron_goblin_captain")
        XCTAssertEqual(fetched.first?.activeMilestoneQuestID, "milestone_first_5_workouts")
    }

    // MARK: Streak calculation

    func testStreakCountsConsecutiveDays() {
        let calendar = Calendar.current
        let now = Date.now
        let dates = (0..<4).compactMap { calendar.date(byAdding: .day, value: -$0, to: now) }
        XCTAssertEqual(RPGProgressionSnapshot.streak(from: dates, calendar: calendar, now: now), 4)
    }

    func testStreakBrokenByGap() {
        let calendar = Calendar.current
        let now = Date.now
        let dates = [0, 1, 3, 4].compactMap { calendar.date(byAdding: .day, value: -$0, to: now) }
        XCTAssertEqual(RPGProgressionSnapshot.streak(from: dates, calendar: calendar, now: now), 2)
    }

    func testStreakSurvivesUntrainedToday() {
        let calendar = Calendar.current
        let now = Date.now
        let dates = (1...3).compactMap { calendar.date(byAdding: .day, value: -$0, to: now) }
        XCTAssertEqual(RPGProgressionSnapshot.streak(from: dates, calendar: calendar, now: now), 3)
        XCTAssertEqual(RPGProgressionSnapshot.streak(from: [], calendar: calendar, now: now), 0)
    }

    // MARK: Registry integrity

    func testEveryBossHasAMilestoneQuest() {
        for boss in RPGBossRegistry.all {
            XCTAssertNotNil(
                RPGBossRegistry.milestoneQuest(for: boss),
                "\(boss.id) references missing quest \(boss.milestoneQuestID)"
            )
        }
        let ids = RPGBossRegistry.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "Boss IDs must be unique")
    }
}
