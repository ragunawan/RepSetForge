import XCTest
@testable import RepSetForge

final class ProgressionServiceTests: XCTestCase {

    // MARK: setXP

    func testSetXP() {
        // base = 5 * 2 = 10, bonus = 185 / 10 = 18.5, total rounds to 29
        XCTAssertEqual(ProgressionService.setXP(reps: 5, weight: 185), 29)
        // bodyweight: base = 10 * 2 = 20, bonus = 0
        XCTAssertEqual(ProgressionService.setXP(reps: 10, weight: 0), 20)
    }

    func testSetXPNormalizesKilogramsToPoundsForTheBonus() {
        // 185 lb ≈ 83.9146 kg; bonus should match the pounds-based formula regardless of unit.
        let poundsXP = ProgressionService.setXP(reps: 5, weight: 185, unit: .pounds)
        let kilogramsXP = ProgressionService.setXP(reps: 5, weight: 83.9146, unit: .kilograms)
        XCTAssertEqual(poundsXP, kilogramsXP)
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

    // MARK: timed/distance XP

    func testDurationXPIsOneXPPerTwoSeconds() {
        XCTAssertEqual(ProgressionService.durationXP(seconds: 60), 30)
        XCTAssertEqual(ProgressionService.durationXP(seconds: 45), 23) // rounds
    }

    func testDistanceXPIsTwentyXPPerMile() {
        XCTAssertEqual(ProgressionService.distanceXP(miles: 3.1), 62)
        XCTAssertEqual(ProgressionService.distanceXP(miles: 0), 0)
    }

    func testSetXPDispatchesByExerciseType() {
        let plank = Exercise(name: "Plank", primaryMuscle: .core, exerciseType: .duration)
        let plankSet = ExerciseSet(setNumber: 1, durationSeconds: 60)
        XCTAssertEqual(ProgressionService.setXP(exercise: plank, set: plankSet), 30)

        let run = Exercise(name: "5K Run", primaryMuscle: .cardio, exerciseType: .distance)
        let runSet = ExerciseSet(setNumber: 1, distanceMiles: 3.1)
        XCTAssertEqual(ProgressionService.setXP(exercise: run, set: runSet), 62)

        let row = Exercise(name: "Rowing", primaryMuscle: .cardio, exerciseType: .cardio)
        let rowSet = ExerciseSet(setNumber: 1, distanceMiles: 2, durationSeconds: 600)
        XCTAssertEqual(ProgressionService.setXP(exercise: row, set: rowSet), 40 + 300)

        let bench = Exercise(name: "Bench Press", primaryMuscle: .chest, exerciseType: .strength)
        let benchSet = ExerciseSet(setNumber: 1, reps: 5, weight: 185)
        XCTAssertEqual(ProgressionService.setXP(exercise: bench, set: benchSet), ProgressionService.setXP(reps: 5, weight: 185))

        let benchKg = Exercise(name: "Bench Press", primaryMuscle: .chest, exerciseType: .strength)
        let benchKgSet = ExerciseSet(setNumber: 1, reps: 5, weight: 83.9146, weightUnit: .kilograms)
        XCTAssertEqual(ProgressionService.setXP(exercise: benchKg, set: benchKgSet), ProgressionService.setXP(reps: 5, weight: 185))
    }

    func testExerciseXPUsesDurationFormulaForTimedExercises() {
        let plank = Exercise(name: "Plank", primaryMuscle: .core, exerciseType: .duration)
        plank.sets = [
            ExerciseSet(setNumber: 1, completed: true, durationSeconds: 60),
            ExerciseSet(setNumber: 2, completed: true, durationSeconds: 30),
            ExerciseSet(setNumber: 3, completed: false, durationSeconds: 120) // excluded
        ]
        XCTAssertEqual(ProgressionService.exerciseXP(plank), 30 + 15)
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

    func testLevelUpCascadesMultipleLevelsInOneCall() {
        // Level 1 needs 100 XP, level 2 needs 200, level 3 needs 300 — 650 XP
        // should cross all three thresholds in a single call, not just the first.
        let character = PlayerCharacter(level: 1, currentXP: 650)
        ProgressionService.levelUpIfNeeded(character: character)
        XCTAssertEqual(character.level, 4)
        XCTAssertEqual(character.currentXP, 50) // 650 - 100 - 200 - 300
    }

    func testMuscleLevelUpCascadesMultipleLevelsInOneCall() {
        let muscle = MuscleProgress(muscleGroup: .chest, level: 1, currentXP: 650)
        ProgressionService.levelUpIfNeeded(muscle: muscle)
        XCTAssertEqual(muscle.level, 4)
        XCTAssertEqual(muscle.currentXP, 50)
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

    func testDistributeXPReportsCharacterLevelUpInResult() {
        let exercise = Exercise(name: "Bench Press", primaryMuscle: .chest)
        exercise.sets = [ExerciseSet(setNumber: 1, reps: 50, weight: 200, completed: true)] // well over 100 XP
        let character = PlayerCharacter(level: 1, currentXP: 90)
        let chest = MuscleProgress(muscleGroup: .chest)

        let questXP = ProgressionService.questXP(exercises: [exercise])
        let result = ProgressionService.distributeXP(questXP: questXP, exercises: [exercise], to: character, and: [chest])

        XCTAssertTrue(result.characterLevelUp.didLevelUp)
        XCTAssertEqual(result.characterLevelUp.oldLevel, 1)
        XCTAssertEqual(result.characterLevelUp.newLevel, character.level)
    }

    func testDistributeXPReportsMuscleLevelUpsInResult() throws {
        let exercise = Exercise(name: "Bench Press", primaryMuscle: .chest)
        exercise.sets = [ExerciseSet(setNumber: 1, reps: 50, weight: 200, completed: true)]
        let character = PlayerCharacter()
        let chest = MuscleProgress(muscleGroup: .chest, level: 1, currentXP: 90)

        let questXP = ProgressionService.questXP(exercises: [exercise])
        let result = ProgressionService.distributeXP(questXP: questXP, exercises: [exercise], to: character, and: [chest])

        let chestLevelUp = try XCTUnwrap(result.muscleLevelUps[.chest])
        XCTAssertTrue(chestLevelUp.didLevelUp)
        XCTAssertEqual(chest.level, 2)
    }

    func testDistributeXPResultReportsNoLevelUpWhenThresholdNotReached() {
        let exercise = Exercise(name: "Bench Press", primaryMuscle: .chest)
        exercise.sets = [ExerciseSet(setNumber: 1, reps: 1, weight: 0, completed: true)] // tiny XP
        let character = PlayerCharacter()
        let chest = MuscleProgress(muscleGroup: .chest)

        let questXP = ProgressionService.questXP(exercises: [exercise])
        let result = ProgressionService.distributeXP(questXP: questXP, exercises: [exercise], to: character, and: [chest])

        XCTAssertFalse(result.characterLevelUp.didLevelUp)
        XCTAssertNil(result.muscleLevelUps[.chest])
    }
}
