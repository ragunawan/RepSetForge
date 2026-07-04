import XCTest
import SwiftData
@testable import RepSetForge

final class AchievementServiceTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUpWithError() throws {
        let schema = Schema([Quest.self, Exercise.self, ExerciseSet.self, PlayerCharacter.self, MuscleProgress.self, Achievement.self, PersonalRecord.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
        for achievement in AchievementService.seedDefinitions() {
            context.insert(achievement)
        }
        try context.save()
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
    }

    func testAchievementUnlock() throws {
        let character = PlayerCharacter(level: 1, completedQuestCount: 1)
        let muscles = MuscleGroup.allCases.map { MuscleProgress(muscleGroup: $0) }

        let unlocked = AchievementService.checkAchievements(character: character, muscles: muscles, context: context)

        XCTAssertTrue(unlocked.contains { $0.key == "first_quest" })
        XCTAssertFalse(unlocked.contains { $0.key == "ten_quests" })

        let fetched = try context.fetch(FetchDescriptor<Achievement>())
        let firstQuest = try XCTUnwrap(fetched.first { $0.key == "first_quest" })
        XCTAssertTrue(firstQuest.unlocked)
    }

    func testAchievementDates() throws {
        let character = PlayerCharacter(level: 2, completedQuestCount: 1)
        let muscles = MuscleGroup.allCases.map { MuscleProgress(muscleGroup: $0) }

        let unlocked = AchievementService.checkAchievements(character: character, muscles: muscles, context: context)
        let levelUp = try XCTUnwrap(unlocked.first { $0.key == "first_level_up" })

        XCTAssertNotNil(levelUp.unlockedDate)
        XCTAssertTrue(levelUp.unlockedDate!.timeIntervalSinceNow < 1)
    }

    func testAchievementsDoNotUnlockTwice() {
        let character = PlayerCharacter(level: 1, completedQuestCount: 1)
        let muscles = MuscleGroup.allCases.map { MuscleProgress(muscleGroup: $0) }

        let firstPass = AchievementService.checkAchievements(character: character, muscles: muscles, context: context)
        let secondPass = AchievementService.checkAchievements(character: character, muscles: muscles, context: context)

        XCTAssertTrue(firstPass.contains { $0.key == "first_quest" })
        XCTAssertFalse(secondPass.contains { $0.key == "first_quest" })
    }

    func testFirstPRUnlocksOnceAPersonalRecordExists() {
        let character = PlayerCharacter()
        let muscles = MuscleGroup.allCases.map { MuscleProgress(muscleGroup: $0) }
        context.insert(PersonalRecord(exerciseName: "Bench Press", recordType: .maxWeight, value: 185, weightUnit: .pounds))

        let unlocked = AchievementService.checkAchievements(character: character, muscles: muscles, context: context)

        XCTAssertTrue(unlocked.contains { $0.key == "first_pr" })
    }

    func testFirstPRDoesNotUnlockWithoutAnyRecords() {
        let character = PlayerCharacter()
        let muscles = MuscleGroup.allCases.map { MuscleProgress(muscleGroup: $0) }

        let unlocked = AchievementService.checkAchievements(character: character, muscles: muscles, context: context)

        XCTAssertFalse(unlocked.contains { $0.key == "first_pr" })
    }

    func testBalancedTrainerRequiresEveryMuscleGroupToHaveXP() {
        let character = PlayerCharacter()
        let muscles = MuscleGroup.allCases.map { MuscleProgress(muscleGroup: $0, totalXP: 10) }

        let unlocked = AchievementService.checkAchievements(character: character, muscles: muscles, context: context)

        XCTAssertTrue(unlocked.contains { $0.key == "balanced_trainer" })
    }

    func testBalancedTrainerDoesNotUnlockIfOneMuscleGroupIsUntrained() {
        let character = PlayerCharacter()
        var muscles = MuscleGroup.allCases.map { MuscleProgress(muscleGroup: $0, totalXP: 10) }
        muscles[0].totalXP = 0

        let unlocked = AchievementService.checkAchievements(character: character, muscles: muscles, context: context)

        XCTAssertFalse(unlocked.contains { $0.key == "balanced_trainer" })
    }

    func testVolumeAchievementSumsUnitNormalizedWeightAcrossCompletedSets() throws {
        let character = PlayerCharacter()
        let muscles = MuscleGroup.allCases.map { MuscleProgress(muscleGroup: $0) }
        let quest = Quest(name: "Push Day", status: .completed)
        let exercise = Exercise(name: "Bench Press", primaryMuscle: .chest)
        // 50 reps * 200 lb = 10,000 lb exactly.
        exercise.sets = [ExerciseSet(setNumber: 1, reps: 50, weight: 200, completed: true, weightUnit: .pounds)]
        quest.exercises = [exercise]
        context.insert(quest)
        try context.save()

        let unlocked = AchievementService.checkAchievements(character: character, muscles: muscles, context: context)

        XCTAssertTrue(unlocked.contains { $0.key == "volume_10k" })
    }

    func testStreakAchievementsUnlockAtEachThreshold() throws {
        let character = PlayerCharacter()
        let muscles = MuscleGroup.allCases.map { MuscleProgress(muscleGroup: $0) }
        let calendar = Calendar.current
        for offset in 0..<7 {
            let quest = Quest(name: "Day \(offset)", status: .completed)
            quest.completedDate = calendar.date(byAdding: .day, value: -offset, to: .now)
            context.insert(quest)
        }
        try context.save()

        let unlocked = AchievementService.checkAchievements(character: character, muscles: muscles, context: context)

        XCTAssertTrue(unlocked.contains { $0.key == "three_day_streak" })
        XCTAssertTrue(unlocked.contains { $0.key == "seven_day_streak" })
        XCTAssertFalse(unlocked.contains { $0.key == "thirty_day_streak" })
    }

    func testTenQuestsUnlocksAtExactlyTenCompletedQuests() {
        let character = PlayerCharacter(completedQuestCount: 10)
        let muscles = MuscleGroup.allCases.map { MuscleProgress(muscleGroup: $0) }

        let unlocked = AchievementService.checkAchievements(character: character, muscles: muscles, context: context)

        XCTAssertTrue(unlocked.contains { $0.key == "ten_quests" })
    }

    func testTenQuestsDoesNotUnlockBelowThreshold() {
        let character = PlayerCharacter(completedQuestCount: 9)
        let muscles = MuscleGroup.allCases.map { MuscleProgress(muscleGroup: $0) }

        let unlocked = AchievementService.checkAchievements(character: character, muscles: muscles, context: context)

        XCTAssertFalse(unlocked.contains { $0.key == "ten_quests" })
    }

    func testLevel10UnlocksAtExactlyLevel10() {
        let character = PlayerCharacter(level: 10)
        let muscles = MuscleGroup.allCases.map { MuscleProgress(muscleGroup: $0) }

        let unlocked = AchievementService.checkAchievements(character: character, muscles: muscles, context: context)

        XCTAssertTrue(unlocked.contains { $0.key == "level_10" })
        XCTAssertTrue(unlocked.contains { $0.key == "first_level_up" }) // level 2 threshold also crossed
    }

    func testLevel10DoesNotUnlockBelowThreshold() {
        let character = PlayerCharacter(level: 9)
        let muscles = MuscleGroup.allCases.map { MuscleProgress(muscleGroup: $0) }

        let unlocked = AchievementService.checkAchievements(character: character, muscles: muscles, context: context)

        XCTAssertFalse(unlocked.contains { $0.key == "level_10" })
    }

    func testHundredSetsUnlocksAtExactlyOneHundredCompletedSets() throws {
        let character = PlayerCharacter()
        let muscles = MuscleGroup.allCases.map { MuscleProgress(muscleGroup: $0) }
        let quest = Quest(name: "Endurance Day", status: .completed)
        let exercise = Exercise(name: "Push-ups", primaryMuscle: .chest)
        exercise.sets = (1...100).map { ExerciseSet(setNumber: $0, reps: 1, weight: 0, completed: true) }
        quest.exercises = [exercise]
        context.insert(quest)
        try context.save()

        let unlocked = AchievementService.checkAchievements(character: character, muscles: muscles, context: context)

        XCTAssertTrue(unlocked.contains { $0.key == "hundred_sets" })
    }

    func testHundredSetsDoesNotCountIncompleteSets() throws {
        let character = PlayerCharacter()
        let muscles = MuscleGroup.allCases.map { MuscleProgress(muscleGroup: $0) }
        let quest = Quest(name: "Endurance Day", status: .completed)
        let exercise = Exercise(name: "Push-ups", primaryMuscle: .chest)
        exercise.sets = (1...100).map { ExerciseSet(setNumber: $0, reps: 1, weight: 0, completed: $0 <= 99) }
        quest.exercises = [exercise]
        context.insert(quest)
        try context.save()

        let unlocked = AchievementService.checkAchievements(character: character, muscles: muscles, context: context)

        XCTAssertFalse(unlocked.contains { $0.key == "hundred_sets" })
    }

    func testStreakAchievementUnlockDateDoesNotChangeOnceUnlocked() throws {
        let character = PlayerCharacter(completedQuestCount: 1)
        let muscles = MuscleGroup.allCases.map { MuscleProgress(muscleGroup: $0) }

        let firstCallDate = Date(timeIntervalSince1970: 1_000_000)
        AchievementService.checkAchievements(character: character, muscles: muscles, context: context, at: firstCallDate)
        let afterFirst = try XCTUnwrap(try context.fetch(FetchDescriptor<Achievement>()).first { $0.key == "first_quest" })
        XCTAssertEqual(afterFirst.unlockedDate, firstCallDate)

        // A second pass, days later, must not overwrite the original unlock date.
        let laterDate = Date(timeIntervalSince1970: 2_000_000)
        AchievementService.checkAchievements(character: character, muscles: muscles, context: context, at: laterDate)
        let afterSecond = try XCTUnwrap(try context.fetch(FetchDescriptor<Achievement>()).first { $0.key == "first_quest" })
        XCTAssertEqual(afterSecond.unlockedDate, firstCallDate)
    }

    func testBrokenStreakOnlyCountsTheRunEndingAtTheMostRecentDay() throws {
        let character = PlayerCharacter()
        let muscles = MuscleGroup.allCases.map { MuscleProgress(muscleGroup: $0) }
        let calendar = Calendar.current
        // 3 consecutive days long ago (days 10-12 back), a gap, then 3 more
        // consecutive days ending today. Combined that's 6 quest-days, but no
        // single unbroken run reaches 7 — only the most-recent 3-day run
        // should count, and 7-day must NOT unlock despite 6 total quests.
        for offset in [0, 1, 2, 10, 11, 12] {
            let quest = Quest(name: "Day \(offset)", status: .completed)
            quest.completedDate = calendar.date(byAdding: .day, value: -offset, to: .now)
            context.insert(quest)
        }
        try context.save()

        let unlocked = AchievementService.checkAchievements(character: character, muscles: muscles, context: context)

        XCTAssertTrue(unlocked.contains { $0.key == "three_day_streak" })
        XCTAssertFalse(unlocked.contains { $0.key == "seven_day_streak" })
    }

    func testTenWorkoutDaysCountsDistinctDaysNotConsecutiveness() throws {
        let character = PlayerCharacter()
        let muscles = MuscleGroup.allCases.map { MuscleProgress(muscleGroup: $0) }
        let calendar = Calendar.current
        // 10 distinct days, but every other day (no streak).
        for offset in 0..<10 {
            let quest = Quest(name: "Day \(offset)", status: .completed)
            quest.completedDate = calendar.date(byAdding: .day, value: -offset * 2, to: .now)
            context.insert(quest)
        }
        try context.save()

        let unlocked = AchievementService.checkAchievements(character: character, muscles: muscles, context: context)

        XCTAssertTrue(unlocked.contains { $0.key == "ten_workout_days" })
        XCTAssertFalse(unlocked.contains { $0.key == "three_day_streak" })
    }
}
