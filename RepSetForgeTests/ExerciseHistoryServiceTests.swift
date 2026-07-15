import Testing
import Foundation
@testable import RepSetForge

struct ExerciseHistoryServiceTests {
    private func makeSet(
        exercise: Exercise,
        weight: Decimal,
        reps: Int,
        sessionDate: Date,
        type: SetType = .working
    ) -> SetEntry {
        let session = WorkoutSession(name: "Test")
        session.startedAt = sessionDate
        let sessionExercise = SessionExercise(exercise: exercise, order: 0)
        sessionExercise.session = session
        let set = SetEntry(index: 0, type: type, weightKg: weight, reps: reps)
        set.completedAt = sessionDate
        set.sessionExercise = sessionExercise
        return set
    }

    @Test func qualifyingSetsExcludesOtherExercisesAndWarmups() {
        let bench = Exercise(name: "Bench Press")
        let squat = Exercise(name: "Squat")
        let now = Date.now

        let benchSet = makeSet(exercise: bench, weight: 100, reps: 8, sessionDate: now)
        let squatSet = makeSet(exercise: squat, weight: 140, reps: 5, sessionDate: now)
        let benchWarmup = makeSet(exercise: bench, weight: 60, reps: 10, sessionDate: now, type: .warmup)

        let qualifying = ExerciseHistoryService.qualifyingSets(exerciseID: bench.id, in: [benchSet, squatSet, benchWarmup])

        #expect(qualifying.count == 1)
        #expect(qualifying[0] === benchSet)
    }

    @Test func trendPointsOnePerSessionUsingBestE1RM() {
        let bench = Exercise(name: "Bench Press")
        let day1 = Date(timeIntervalSince1970: 1_000_000)
        let day2 = Date(timeIntervalSince1970: 2_000_000)

        let session1SetA = makeSet(exercise: bench, weight: 100, reps: 8, sessionDate: day1)
        // Same session as session1SetA — share the same sessionExercise/session.
        let session1SetB = SetEntry(index: 1, weightKg: 105, reps: 5)
        session1SetB.completedAt = day1
        session1SetB.sessionExercise = session1SetA.sessionExercise

        let session2Set = makeSet(exercise: bench, weight: 110, reps: 6, sessionDate: day2)

        let qualifying = [session1SetA, session1SetB, session2Set]
        let points = ExerciseHistoryService.trendPoints(from: qualifying)

        #expect(points.count == 2)
        #expect(points[0].date == day1)
        #expect(points[1].date == day2)
        // session1's best e1RM should come from whichever set produces the higher value.
        let expectedDay1E1RM = max(
            session1SetA.estimatedOneRepMax ?? 0,
            session1SetB.estimatedOneRepMax ?? 0
        )
        #expect(points[0].e1RM == expectedDay1E1RM)
    }

    @Test func bestStatsFindsMaximumsAcrossAllSets() {
        let bench = Exercise(name: "Bench Press")
        let sets = [
            makeSet(exercise: bench, weight: 90, reps: 10, sessionDate: .now),
            makeSet(exercise: bench, weight: 100, reps: 8, sessionDate: .now),
            makeSet(exercise: bench, weight: 80, reps: 12, sessionDate: .now),
        ]

        let stats = ExerciseHistoryService.bestStats(from: sets)

        #expect(stats.bestWeight == 100)
        #expect(stats.repsAtBestWeight == 8)
        #expect(stats.bestVolumeSet == 960) // 80 * 12
    }

    @Test func emptyHistoryYieldsNilStats() {
        let stats = ExerciseHistoryService.bestStats(from: [])
        #expect(stats.bestWeight == nil)
        #expect(stats.bestE1RM == nil)
        #expect(stats.bestVolumeSet == nil)
        #expect(stats.repsAtBestWeight == nil)
    }
}
