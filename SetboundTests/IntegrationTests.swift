import XCTest
import SwiftData
@testable import Setbound

/// End-to-end: create a quest, add an exercise, log completed sets, complete the
/// quest, and verify XP flows through to the character and its muscle groups.
final class IntegrationTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUpWithError() throws {
        let schema = Schema([Quest.self, Exercise.self, ExerciseSet.self, PlayerCharacter.self, MuscleProgress.self, Achievement.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
    }

    func testQuestCompletionFlow() throws {
        let character = PlayerCharacter()
        context.insert(character)
        let muscles = MuscleGroup.allCases.map { MuscleProgress(muscleGroup: $0) }
        muscles.forEach { context.insert($0) }
        for achievement in AchievementService.seedDefinitions() {
            context.insert(achievement)
        }

        let quest = Quest(name: "Test Quest", status: .active)
        let benchPress = Exercise(name: "Bench Press", primaryMuscle: .chest, secondaryMuscles: [.shoulders, .arms])
        benchPress.sets = [
            ExerciseSet(setNumber: 1, reps: 5, weight: 185, completed: true),
            ExerciseSet(setNumber: 2, reps: 5, weight: 185, completed: true),
            ExerciseSet(setNumber: 3, reps: 3, weight: 185, completed: true)
        ]
        quest.exercises = [benchPress]
        context.insert(quest)
        try context.save()

        // Mirrors QuestDetailView.completeQuest()
        let xp = ProgressionService.questXP(exercises: quest.exercises)
        let distribution = ProgressionService.distributeXP(questXP: xp, exercises: quest.exercises, to: character, and: muscles)
        quest.status = .completed
        quest.completedDate = .now
        quest.totalXP = xp
        character.completedQuestCount += 1
        let unlocked = AchievementService.checkAchievements(character: character, muscles: muscles, context: context)
        try context.save()

        XCTAssertEqual(quest.status, .completed)
        XCTAssertGreaterThan(quest.totalXP, 0)
        XCTAssertEqual(character.totalXP, xp)
        XCTAssertEqual(character.completedQuestCount, 1)

        let chest = try XCTUnwrap(muscles.first { $0.muscleGroup == .chest })
        XCTAssertGreaterThan(chest.totalXP, 0)
        XCTAssertEqual(chest.totalXP, distribution.muscleXP[.chest])

        let legs = try XCTUnwrap(muscles.first { $0.muscleGroup == .legs })
        XCTAssertEqual(legs.totalXP, 0) // untouched muscle group

        XCTAssertTrue(unlocked.contains { $0.key == "first_quest" })
    }
}
