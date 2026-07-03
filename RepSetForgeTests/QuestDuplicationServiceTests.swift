import XCTest
@testable import RepSetForge

final class QuestDuplicationServiceTests: XCTestCase {

    func testDuplicateCopiesNameAndResetsStatus() {
        let quest = Quest(name: "Push Day", status: .completed)
        quest.totalXP = 250
        quest.completedDate = .now

        let copy = QuestDuplicationService.duplicate(quest)

        XCTAssertEqual(copy.name, "Push Day")
        XCTAssertEqual(copy.status, .active)
        XCTAssertEqual(copy.totalXP, 0)
        XCTAssertNil(copy.completedDate)
    }

    func testDuplicatePreservesEachSetsExactRepsAndWeight() {
        let quest = Quest(name: "Push Day", status: .completed)
        let bench = Exercise(name: "Bench Press", primaryMuscle: .chest, secondaryMuscles: [.arms], notes: "Pause at chest", defaultRestSeconds: 90)
        bench.sets = [
            ExerciseSet(setNumber: 1, reps: 8, weight: 135, completed: true),
            ExerciseSet(setNumber: 2, reps: 6, weight: 145, completed: true),
            ExerciseSet(setNumber: 3, reps: 5, weight: 155, completed: true),
        ]
        quest.exercises = [bench]

        let copy = QuestDuplicationService.duplicate(quest)

        XCTAssertEqual(copy.exercises.count, 1)
        let copiedExercise = copy.exercises[0]
        XCTAssertEqual(copiedExercise.name, "Bench Press")
        XCTAssertEqual(copiedExercise.primaryMuscle, .chest)
        XCTAssertEqual(copiedExercise.secondaryMuscles, [.arms])
        XCTAssertEqual(copiedExercise.notes, "Pause at chest")
        XCTAssertEqual(copiedExercise.defaultRestSeconds, 90)

        let copiedSets = copiedExercise.sets.sorted { $0.setNumber < $1.setNumber }
        XCTAssertEqual(copiedSets.map(\.setNumber), [1, 2, 3])
        XCTAssertEqual(copiedSets.map(\.reps), [8, 6, 5])
        XCTAssertEqual(copiedSets.map(\.weight), [135, 145, 155])
        XCTAssertTrue(copiedSets.allSatisfy { !$0.completed })
    }

    func testDuplicateWithNoSetsCreatesExerciseWithEmptySets() {
        let quest = Quest(name: "Core Trial", status: .completed)
        quest.exercises = [Exercise(name: "Plank", primaryMuscle: .core)]

        let copy = QuestDuplicationService.duplicate(quest)

        XCTAssertTrue(copy.exercises[0].sets.isEmpty)
    }

    func testDuplicatePreservesExerciseTypeDistanceAndDuration() {
        let quest = Quest(name: "Cardio Day", status: .completed)
        let run = Exercise(name: "5K Run", primaryMuscle: .cardio, exerciseType: .cardio)
        run.sets = [ExerciseSet(setNumber: 1, completed: true, distanceMiles: 3.1, durationSeconds: 1500)]
        quest.exercises = [run]

        let copy = QuestDuplicationService.duplicate(quest)

        XCTAssertEqual(copy.exercises[0].exerciseType, .cardio)
        XCTAssertEqual(copy.exercises[0].sets[0].distanceMiles, 3.1)
        XCTAssertEqual(copy.exercises[0].sets[0].durationSeconds, 1500)
    }

    func testDuplicateIsIndependentOfSourceQuest() {
        let quest = Quest(name: "Leg Day", status: .completed)
        let squat = Exercise(name: "Squat", primaryMuscle: .legs)
        squat.sets = [ExerciseSet(setNumber: 1, reps: 5, weight: 225, completed: true)]
        quest.exercises = [squat]

        let copy = QuestDuplicationService.duplicate(quest)
        copy.exercises[0].sets[0].reps = 10

        XCTAssertEqual(squat.sets[0].reps, 5)
    }
}
