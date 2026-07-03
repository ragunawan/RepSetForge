import XCTest
@testable import Setbound

final class ExerciseTemplateServiceTests: XCTestCase {

    func testMakeExerciseCopiesTemplateFields() {
        let template = ExerciseTemplate(
            name: "Bench Press",
            primaryMuscle: .chest,
            secondaryMuscles: [.shoulders, .arms],
            notes: "Pause at chest",
            defaultSetCount: 3,
            defaultReps: 8,
            defaultWeight: 135
        )

        let exercise = ExerciseTemplateService.makeExercise(from: template)

        XCTAssertEqual(exercise.name, "Bench Press")
        XCTAssertEqual(exercise.primaryMuscle, .chest)
        XCTAssertEqual(Set(exercise.secondaryMuscles), [.shoulders, .arms])
        XCTAssertEqual(exercise.notes, "Pause at chest")
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

    func testMakeTemplateCopiesGivenSkillDefinition() {
        let template = ExerciseTemplateService.makeTemplate(
            name: "Rows",
            primaryMuscle: .back,
            secondaryMuscles: [.arms],
            notes: "Keep elbows tucked",
            defaultSetCount: 3,
            defaultReps: 10,
            defaultWeight: 95
        )

        XCTAssertEqual(template.name, "Rows")
        XCTAssertEqual(template.primaryMuscle, .back)
        XCTAssertEqual(template.secondaryMuscles, [.arms])
        XCTAssertEqual(template.notes, "Keep elbows tucked")
        XCTAssertEqual(template.defaultSetCount, 3)
        XCTAssertEqual(template.defaultReps, 10)
        XCTAssertEqual(template.defaultWeight, 95)
    }
}
