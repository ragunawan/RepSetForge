import XCTest
@testable import SetCraft

final class ProgressionServiceTests: XCTestCase {

    // MARK: setXP

    func testSetXP() {
        // base = 5 * 2 = 10, bonus = 185 / 10 = 18.5, total rounds to 29
        XCTAssertEqual(ProgressionService.setXP(reps: 5, weight: 185), 29)
        // bodyweight: base = 10 * 2 = 20, bonus = 0
        XCTAssertEqual(ProgressionService.setXP(reps: 10, weight: 0), 20)
    }

    // MARK: questXP

    func testQuestXP() {
        let exercise = Exercise(name: "Bench Press", primaryMuscle: .chest)
        exercise.sets = [
            ExerciseSet(setNumber: 1, reps: 5, weight: 135, completed: true),
            ExerciseSet(setNumber: 2, reps: 5, weight: 135, completed: true),
            ExerciseSet(setNumber: 3, reps: 5, weight: 135, completed: false) // not completed, excluded
        ]
        let expectedPerSet = ProgressionService.setXP(reps: 5, weight: 135)
        XCTAssertEqual(ProgressionService.questXP(exercises: [exercise]), expectedPerSet * 2)
    }

    // MARK: leveling

    func testLevelUp() {
        let character = PlayerCharacter(level: 1, currentXP: 90)
        character.currentXP += 20 // crosses the level-1 threshold of 100
        ProgressionService.levelUpIfNeeded(character: character)
        XCTAssertEqual(character.level, 2)
        XCTAssertEqual(character.currentXP, 10) // 110 - 100 carried over
    }

    func testLevelUpIfNeeded() {
        let muscle = MuscleProgress(muscleGroup: .chest, level: 1, currentXP: 150)
        ProgressionService.levelUpIfNeeded(muscle: muscle)
        XCTAssertEqual(muscle.level, 2)
        XCTAssertEqual(muscle.currentXP, 50) // 150 - 100 carried over
    }

    func testCharacterTitleUpdatesOnLevelUp() {
        let character = PlayerCharacter(level: 4, currentXP: 400)
        ProgressionService.levelUpIfNeeded(character: character)
        XCTAssertEqual(character.level, 5)
        XCTAssertEqual(character.title, "Iron Trainee")
    }

    // MARK: muscle distribution

    func testMuscleGroupXPDistribution() {
        let exercise = Exercise(name: "Bench Press", primaryMuscle: .chest, secondaryMuscles: [.arms, .shoulders])
        exercise.sets = [ExerciseSet(setNumber: 1, reps: 40, weight: 100, completed: true)] // xp = 80 + 10 = 90
        let character = PlayerCharacter()
        let chest = MuscleProgress(muscleGroup: .chest)
        let arms = MuscleProgress(muscleGroup: .arms)
        let shoulders = MuscleProgress(muscleGroup: .shoulders)
        let legs = MuscleProgress(muscleGroup: .legs)

        let questXP = ProgressionService.questXP(exercises: [exercise])
        let result = ProgressionService.distributeXP(
            questXP: questXP,
            exercises: [exercise],
            to: character,
            and: [chest, arms, shoulders, legs]
        )

        XCTAssertEqual(result.muscleXP[.chest], 90)
        XCTAssertEqual(result.muscleXP[.arms], 36) // 40% of 90, rounded
        XCTAssertEqual(result.muscleXP[.shoulders], 36)
        XCTAssertNil(result.muscleXP[.legs])
        XCTAssertEqual(character.totalXP, questXP)
        XCTAssertEqual(legs.currentXP, 0)
    }
}
