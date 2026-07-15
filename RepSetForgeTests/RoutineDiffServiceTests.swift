import Testing
import Foundation
@testable import RepSetForge

struct RoutineDiffServiceTests {
    private func makeCompletedSet(index: Int) -> SetEntry {
        let set = SetEntry(index: index, weightKg: 60, reps: 8)
        set.completedAt = .now
        return set
    }

    @Test func exercisePerformedButNotInRoutineIsAdded() {
        let routine = Routine(name: "Push Day A")
        let benchPress = Exercise(name: "Bench Press")
        routine.items = [RoutineItem(exercise: benchPress, order: 0, targetSets: 3)]

        let session = WorkoutSession(name: "Push Day A", routine: routine)
        let cableFly = Exercise(name: "Cable Fly")
        let sessionExercise = SessionExercise(exercise: cableFly, order: 1)
        sessionExercise.setEntries = [makeCompletedSet(index: 0), makeCompletedSet(index: 1)]
        session.sessionExercises = [sessionExercise]

        let changes = RoutineDiffService.diff(session: session, routine: routine)

        #expect(changes.count == 1)
        #expect(changes.first?.exercise.name == "Cable Fly")
        if case .exerciseAdded(let setCount) = changes.first?.kind {
            #expect(setCount == 2)
        } else {
            Issue.record("Expected .exerciseAdded")
        }
    }

    @Test func routineExerciseNotPerformedIsRemoved() {
        let routine = Routine(name: "Push Day A")
        let benchPress = Exercise(name: "Bench Press")
        let lateralRaise = Exercise(name: "Lateral Raise")
        routine.items = [
            RoutineItem(exercise: benchPress, order: 0, targetSets: 3),
            RoutineItem(exercise: lateralRaise, order: 1, targetSets: 3),
        ]

        let session = WorkoutSession(name: "Push Day A", routine: routine)
        let sessionExercise = SessionExercise(exercise: benchPress, order: 0)
        sessionExercise.setEntries = [makeCompletedSet(index: 0)]
        session.sessionExercises = [sessionExercise]

        let changes = RoutineDiffService.diff(session: session, routine: routine)

        #expect(changes.count == 1)
        #expect(changes.first?.exercise.name == "Lateral Raise")
        #expect(changes.first?.kind == .exerciseRemoved)
    }

    @Test func differingSetCountIsFlagged() {
        let routine = Routine(name: "Push Day A")
        let benchPress = Exercise(name: "Bench Press")
        routine.items = [RoutineItem(exercise: benchPress, order: 0, targetSets: 3)]

        let session = WorkoutSession(name: "Push Day A", routine: routine)
        let sessionExercise = SessionExercise(exercise: benchPress, order: 0)
        sessionExercise.setEntries = (0..<5).map(makeCompletedSet)
        session.sessionExercises = [sessionExercise]

        let changes = RoutineDiffService.diff(session: session, routine: routine)

        #expect(changes.count == 1)
        #expect(changes.first?.kind == .setCountChanged(from: 3, to: 5))
    }

    @Test func matchingSetCountProducesNoDiff() {
        let routine = Routine(name: "Push Day A")
        let benchPress = Exercise(name: "Bench Press")
        routine.items = [RoutineItem(exercise: benchPress, order: 0, targetSets: 3)]

        let session = WorkoutSession(name: "Push Day A", routine: routine)
        let sessionExercise = SessionExercise(exercise: benchPress, order: 0)
        sessionExercise.setEntries = (0..<3).map(makeCompletedSet)
        session.sessionExercises = [sessionExercise]

        let changes = RoutineDiffService.diff(session: session, routine: routine)

        #expect(changes.isEmpty)
    }

    @Test func incompleteSetsDoNotCountTowardAddedOrSetCountDiffs() {
        let routine = Routine(name: "Push Day A")
        let benchPress = Exercise(name: "Bench Press")
        routine.items = [RoutineItem(exercise: benchPress, order: 0, targetSets: 3)]

        let session = WorkoutSession(name: "Push Day A", routine: routine)
        let sessionExercise = SessionExercise(exercise: benchPress, order: 0)
        // All three uncompleted — shouldn't register as a set-count change,
        // and (per the exercise-added rule) an exercise with zero completed
        // sets shouldn't register as added either.
        let incomplete = SetEntry(index: 0, weightKg: 60, reps: 8)
        sessionExercise.setEntries = [incomplete]
        session.sessionExercises = [sessionExercise]

        let changes = RoutineDiffService.diff(session: session, routine: routine)

        #expect(changes.isEmpty)
    }
}
