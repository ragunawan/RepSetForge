import XCTest
import SwiftData
@testable import RepSetForge

final class PrivacyDataServiceTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUpWithError() throws {
        let schema = Schema([Quest.self, Exercise.self, ExerciseSet.self, PlayerCharacter.self, MuscleProgress.self, Achievement.self, PersonalRecord.self, SkillProgress.self, OwnedEquipment.self, RPGEncounterState.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)

        context.insert(PlayerCharacter())
        for group in MuscleGroup.allCases {
            context.insert(MuscleProgress(muscleGroup: group))
        }
        for achievement in AchievementService.seedDefinitions() {
            context.insert(achievement)
        }
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
    }

    private func completedQuest(reps: Int, weight: Double) -> Quest {
        let quest = Quest(name: "Push Day", status: .completed)
        quest.completedDate = .now
        let exercise = Exercise(name: "Bench Press", primaryMuscle: .chest)
        exercise.sets.append(ExerciseSet(setNumber: 1, reps: reps, weight: weight, completed: true))
        quest.exercises.append(exercise)
        context.insert(quest)
        return quest
    }

    func testDeletesAllQuestsAndCascadesToExercisesAndSets() throws {
        _ = completedQuest(reps: 10, weight: 100)
        _ = completedQuest(reps: 8, weight: 110)
        try context.save()

        PrivacyDataService.deleteAllWorkoutData(context: context)

        XCTAssertTrue(try context.fetch(FetchDescriptor<Quest>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<Exercise>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<ExerciseSet>()).isEmpty)
    }

    func testResetsCharacterAndMuscleXPToBaseline() throws {
        let quest = completedQuest(reps: 10, weight: 100)
        let character = try XCTUnwrap(context.fetch(FetchDescriptor<PlayerCharacter>()).first)
        let muscles = try context.fetch(FetchDescriptor<MuscleProgress>())
        let distribution = ProgressionService.distributeXP(questXP: ProgressionService.questXP(exercises: quest.exercises), exercises: quest.exercises, to: character, and: muscles)
        quest.totalXP = distribution.totalXP
        try context.save()
        XCTAssertGreaterThan(character.totalXP, 0)

        PrivacyDataService.deleteAllWorkoutData(context: context)

        let resetCharacter = try XCTUnwrap(context.fetch(FetchDescriptor<PlayerCharacter>()).first)
        XCTAssertEqual(resetCharacter.totalXP, 0)
        XCTAssertEqual(resetCharacter.level, 1)
    }

    func testIsIdempotentWithNoExistingData() {
        // Deleting when there's nothing to delete shouldn't throw or crash.
        PrivacyDataService.deleteAllWorkoutData(context: context)
        XCTAssertTrue((try? context.fetch(FetchDescriptor<Quest>()))?.isEmpty ?? false)
    }

    func testDoesNotDeleteTheCharacterOrMuscleRowsThemselves() throws {
        _ = completedQuest(reps: 10, weight: 100)
        try context.save()

        PrivacyDataService.deleteAllWorkoutData(context: context)

        XCTAssertEqual(try context.fetch(FetchDescriptor<PlayerCharacter>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<MuscleProgress>()).count, MuscleGroup.allCases.count)
    }
}
