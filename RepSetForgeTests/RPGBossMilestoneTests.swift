import XCTest
import SwiftData
@testable import RepSetForge

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

    /// Edge case: a rest day (no entry "today") must not be indistinguishable
    /// from a broken streak — grace lasts exactly one day, not more.
    func testStreakResetsOnceAFullDayPassesWithNoTraining() {
        let calendar = Calendar.current
        let now = Date.now
        // Last logged workout was 2 days ago — one full untrained day (yesterday)
        // has already elapsed, so the streak must be gone, not just "paused."
        let dates = (2...5).compactMap { calendar.date(byAdding: .day, value: -$0, to: now) }
        XCTAssertEqual(RPGProgressionSnapshot.streak(from: dates, calendar: calendar, now: now), 0)
    }

    /// Edge case: duplicate/multiple completions on the same calendar day must
    /// collapse to a single day, not inflate the streak count.
    func testStreakDoesNotInflateFromMultipleCompletionsOnOneDay() {
        let calendar = Calendar.current
        let now = Date.now
        var dates: [Date] = []
        for dayOffset in 0..<3 {
            let day = calendar.date(byAdding: .day, value: -dayOffset, to: now)!
            dates.append(day)
            dates.append(calendar.date(byAdding: .hour, value: -1, to: day)!)
            dates.append(calendar.date(byAdding: .hour, value: -2, to: day)!)
        }
        XCTAssertEqual(RPGProgressionSnapshot.streak(from: dates, calendar: calendar, now: now), 3)
    }

    /// Edge case: a late-night workout just before midnight and another just
    /// after midnight the next calendar day must count as two consecutive
    /// days, not the same day and not a broken streak.
    func testLateNightWorkoutsNearMidnightCountAsConsecutiveDays() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let justBeforeMidnight = calendar.date(byAdding: .init(day: -1, hour: 23, minute: 58), to: today)!
        let justAfterMidnight = calendar.date(byAdding: .init(minute: 2), to: today)!

        let streak = RPGProgressionSnapshot.streak(
            from: [justBeforeMidnight, justAfterMidnight],
            calendar: calendar,
            now: justAfterMidnight
        )

        XCTAssertEqual(streak, 2)
    }

    /// Edge case: the streak must stay correct across a Daylight Saving Time
    /// transition, where a "day" is 23 or 25 hours long instead of 24 — the
    /// implementation must walk calendar days, not fixed 86,400s intervals.
    func testStreakIsUnaffectedByDaylightSavingTransition() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        // US spring-forward 2024: March 10, clocks jump 2am -> 3am (23-hour day).
        var components = DateComponents()
        components.year = 2024
        components.month = 3
        components.day = 8
        components.hour = 12
        let start = calendar.date(from: components)!

        let dates = (0..<4).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
        let lastDay = dates.last!

        XCTAssertEqual(RPGProgressionSnapshot.streak(from: dates, calendar: calendar, now: lastDay), 4)
    }

    /// Edge case: the function must be deterministic off the given `calendar`
    /// (and its time zone), not hidden global/device state.
    func testStreakIsDeterministicForAnExplicitTimeZone() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Pacific/Kiritimati")! // UTC+14, an extreme offset
        let now = Date.now
        let dates = (0..<5).compactMap { calendar.date(byAdding: .day, value: -$0, to: now) }
        XCTAssertEqual(RPGProgressionSnapshot.streak(from: dates, calendar: calendar, now: now), 5)
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
