import XCTest
@testable import RepSetForge

final class ExerciseTemplateServiceTests: XCTestCase {

    func testMakeExerciseCopiesTemplateFields() {
        let template = ExerciseTemplate(
            name: "Bench Press",
            primaryMuscle: .chest,
            secondaryMuscles: [.shoulders, .arms],
            notes: "Pause at chest",
            defaultSetCount: 3,
            defaultReps: 8,
            defaultWeight: 135,
            defaultRestSeconds: 90
        )

        let exercise = ExerciseTemplateService.makeExercise(from: template)

        XCTAssertEqual(exercise.name, "Bench Press")
        XCTAssertEqual(exercise.primaryMuscle, .chest)
        XCTAssertEqual(Set(exercise.secondaryMuscles), [.shoulders, .arms])
        XCTAssertEqual(exercise.notes, "Pause at chest")
        XCTAssertEqual(exercise.defaultRestSeconds, 90)
    }

    func testExerciseDefaultsToSixtySecondRestWhenUnspecified() {
        let exercise = Exercise(name: "Plank", primaryMuscle: .core)
        XCTAssertEqual(exercise.defaultRestSeconds, 60)
    }

    func testMakeExercisePrefillsSetsFromDefaultScheme() {
        let template = ExerciseTemplate(name: "Squat", primaryMuscle: .legs, defaultSetCount: 4, defaultReps: 6, defaultWeight: 225)

        let exercise = ExerciseTemplateService.makeExercise(from: template)

        XCTAssertEqual(exercise.sets.count, 4)
        XCTAssertEqual(exercise.sets.map(\.setNumber), [1, 2, 3, 4])
        XCTAssertTrue(exercise.sets.allSatisfy { $0.reps == 6 && $0.weight == 225 && !$0.completed })
    }

    func testMakeExerciseWithZeroSetCountCreatesNoSets() {
        let template = ExerciseTemplate(name: "Plank", primaryMuscle: .core, defaultSetCount: 0)

        let exercise = ExerciseTemplateService.makeExercise(from: template)

        XCTAssertTrue(exercise.sets.isEmpty)
    }

    func testMakeExerciseCarriesDurationTypeAndDefaults() {
        let template = ExerciseTemplate(
            name: "Plank",
            primaryMuscle: .core,
            defaultSetCount: 3,
            exerciseType: .duration,
            defaultDurationSeconds: 45
        )

        let exercise = ExerciseTemplateService.makeExercise(from: template)

        XCTAssertEqual(exercise.exerciseType, .duration)
        XCTAssertTrue(exercise.sets.allSatisfy { $0.durationSeconds == 45 })
    }

    func testMakeExerciseCarriesCardioTypeDistanceAndDuration() {
        let template = ExerciseTemplate(
            name: "5K Run",
            primaryMuscle: .cardio,
            defaultSetCount: 1,
            exerciseType: .cardio,
            defaultDistanceMiles: 3.1,
            defaultDurationSeconds: 1500
        )

        let exercise = ExerciseTemplateService.makeExercise(from: template)

        XCTAssertEqual(exercise.exerciseType, .cardio)
        XCTAssertEqual(exercise.sets[0].distanceMiles, 3.1)
        XCTAssertEqual(exercise.sets[0].durationSeconds, 1500)
    }

    func testMakeTemplateCopiesGivenSkillDefinition() {
        let template = ExerciseTemplateService.makeTemplate(
            name: "Rows",
            primaryMuscle: .back,
            secondaryMuscles: [.arms],
            notes: "Keep elbows tucked",
            defaultSetCount: 3,
            defaultReps: 10,
            defaultWeight: 95,
            defaultRestSeconds: 45
        )

        XCTAssertEqual(template.name, "Rows")
        XCTAssertEqual(template.primaryMuscle, .back)
        XCTAssertEqual(template.secondaryMuscles, [.arms])
        XCTAssertEqual(template.notes, "Keep elbows tucked")
        XCTAssertEqual(template.defaultSetCount, 3)
        XCTAssertEqual(template.defaultReps, 10)
        XCTAssertEqual(template.defaultWeight, 95)
        XCTAssertEqual(template.defaultRestSeconds, 45)
        XCTAssertEqual(template.exerciseType, .strength)
    }

    func testMakeTemplateCarriesNonStrengthTypeAndMeasurements() {
        let template = ExerciseTemplateService.makeTemplate(
            name: "5K Run",
            primaryMuscle: .cardio,
            secondaryMuscles: [],
            notes: "",
            defaultSetCount: 1,
            defaultReps: 0,
            defaultWeight: 0,
            exerciseType: .cardio,
            defaultDistanceMiles: 3.1,
            defaultDurationSeconds: 1500
        )

        XCTAssertEqual(template.exerciseType, .cardio)
        XCTAssertEqual(template.defaultDistanceMiles, 3.1)
        XCTAssertEqual(template.defaultDurationSeconds, 1500)
    }
}
