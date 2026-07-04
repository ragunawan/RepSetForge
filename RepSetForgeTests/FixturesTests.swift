import XCTest
import SwiftData
@testable import RepSetForge

final class FixturesTests: XCTestCase {
    func testMakeContainerRoundTripsInsertedData() throws {
        let container = Fixtures.makeContainer()
        let context = ModelContext(container)
        context.insert(Fixtures.makeCharacter(level: 3))
        try context.save()

        let characters = try context.fetch(FetchDescriptor<PlayerCharacter>())
        XCTAssertEqual(characters.first?.level, 3)
    }

    func testMakeMusclesCoversEveryMuscleGroupExactlyOnce() {
        let muscles = Fixtures.makeMuscles()
        XCTAssertEqual(Set(muscles.map(\.muscleGroup)), Set(MuscleGroup.allCases))
        XCTAssertEqual(muscles.count, MuscleGroup.allCases.count)
    }

    func testMakeExerciseDefaultsToOneCompletedSet() {
        let exercise = Fixtures.makeExercise()
        XCTAssertEqual(exercise.name, "Bench Press")
        XCTAssertEqual(exercise.primaryMuscle, .chest)
        XCTAssertEqual(exercise.sets.count, 1)
        XCTAssertTrue(exercise.sets[0].completed)
    }

    func testMakeExerciseNumbersSetsInOrder() {
        let exercise = Fixtures.makeExercise(sets: [(8, 135, true), (6, 145, false), (10, 0, true)])
        let numbers = exercise.sets.sorted { $0.setNumber < $1.setNumber }.map(\.setNumber)
        XCTAssertEqual(numbers, [1, 2, 3])
    }

    func testMakeQuestOnlySetsCompletedDateWhenStatusIsCompleted() {
        let planned = Fixtures.makeQuest(status: .planned)
        XCTAssertNil(planned.completedDate)

        let completed = Fixtures.makeQuest(status: .completed)
        XCTAssertNotNil(completed.completedDate)
    }

    func testMakeQuestAppliesDaysAgoOffset() {
        let quest = Fixtures.makeQuest(daysAgo: 5)
        let expected = Calendar.current.date(byAdding: .day, value: -5, to: .now)!
        XCTAssertEqual(
            Calendar.current.startOfDay(for: quest.date),
            Calendar.current.startOfDay(for: expected)
        )
    }

    func testMakeCompletedQuestProducesAQuestWhoseXPMatchesTheFormula() {
        let quest = Fixtures.makeCompletedQuest(reps: 5, weight: 185)
        let expectedXP = ProgressionService.setXP(reps: 5, weight: 185)
        XCTAssertEqual(ProgressionService.questXP(exercises: quest.exercises), expectedXP)
        XCTAssertEqual(quest.status, .completed)
        XCTAssertNotNil(quest.completedDate)
    }

    func testSeedAchievementsInsertsEveryDefinitionUnlockedFalse() throws {
        let container = Fixtures.makeContainer()
        let context = ModelContext(container)
        Fixtures.seedAchievements(context: context)
        try context.save()

        let achievements = try context.fetch(FetchDescriptor<Achievement>())
        XCTAssertEqual(achievements.count, AchievementService.definitions.count)
        XCTAssertTrue(achievements.allSatisfy { !$0.unlocked })
    }
}
