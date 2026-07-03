import XCTest
import SwiftData
@testable import SetCraft

final class AchievementServiceTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUpWithError() throws {
        let schema = Schema([Quest.self, Exercise.self, ExerciseSet.self, PlayerCharacter.self, MuscleProgress.self, Achievement.self])
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
}
