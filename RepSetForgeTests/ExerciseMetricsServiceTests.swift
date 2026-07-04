import XCTest
@testable import RepSetForge

final class ExerciseMetricsServiceTests: XCTestCase {

    private func completedQuest(daysAgo: Int, exercises: [Exercise]) -> Quest {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now)!
        let quest = Quest(name: "Quest", date: date, status: .completed)
        quest.completedDate = date
        for exercise in exercises {
            quest.exercises.append(exercise)
        }
        return quest
    }

    private func exercise(name: String, sets: [(reps: Int, weight: Double, unit: WeightUnit)]) -> Exercise {
        let exercise = Exercise(name: name, primaryMuscle: .chest)
        for (index, set) in sets.enumerated() {
            exercise.sets.append(ExerciseSet(setNumber: index + 1, reps: set.reps, weight: set.weight, completed: true, weightUnit: set.unit))
        }
        return exercise
    }

    func testNilForBlankName() {
        XCTAssertNil(ExerciseMetricsService.metrics(for: "  ", in: []))
    }

    func testNilWhenNeverLogged() {
        let quest = completedQuest(daysAgo: 0, exercises: [exercise(name: "Squat", sets: [(10, 100, .pounds)])])
        XCTAssertNil(ExerciseMetricsService.metrics(for: "Bench Press", in: [quest]))
    }

    func testMatchesCaseAndWhitespaceInsensitively() {
        let quest = completedQuest(daysAgo: 0, exercises: [exercise(name: "  bench press  ", sets: [(10, 100, .pounds)])])
        let metrics = ExerciseMetricsService.metrics(for: "Bench Press", in: [quest])
        XCTAssertNotNil(metrics)
    }

    func testAllTimeMaxWeightAndBestVolume() {
        let session1 = completedQuest(daysAgo: 10, exercises: [exercise(name: "Bench Press", sets: [(10, 100, .pounds), (10, 100, .pounds)])])
        let session2 = completedQuest(daysAgo: 3, exercises: [exercise(name: "Bench Press", sets: [(5, 150, .pounds)])])
        let metrics = try! XCTUnwrap(ExerciseMetricsService.metrics(for: "Bench Press", in: [session1, session2]))

        XCTAssertEqual(metrics.allTimeMaxWeight, 150)
        // session1 volume = 10*100 + 10*100 = 2000; session2 = 5*150 = 750
        XCTAssertEqual(metrics.allTimeBestVolume, 2000)
    }

    func testHistoryIsChronologicalOldestFirst() {
        let recent = completedQuest(daysAgo: 1, exercises: [exercise(name: "Squat", sets: [(10, 100, .pounds)])])
        let old = completedQuest(daysAgo: 20, exercises: [exercise(name: "Squat", sets: [(10, 100, .pounds)])])
        let metrics = try! XCTUnwrap(ExerciseMetricsService.metrics(for: "Squat", in: [recent, old]))
        XCTAssertEqual(metrics.history.count, 2)
        XCTAssertLessThan(metrics.history[0].date, metrics.history[1].date)
    }

    func testNormalizesKilogramsToPounds() {
        let quest = completedQuest(daysAgo: 0, exercises: [exercise(name: "Deadlift", sets: [(5, 100, .kilograms)])])
        let metrics = try! XCTUnwrap(ExerciseMetricsService.metrics(for: "Deadlift", in: [quest]))
        let expectedWeight = WeightUnit.kilograms.convert(100, to: .pounds)
        XCTAssertEqual(metrics.allTimeMaxWeight, expectedWeight, accuracy: 0.01)
    }

    func testIgnoresIncompleteSets() {
        let ex = Exercise(name: "Row", primaryMuscle: .back)
        ex.sets.append(ExerciseSet(setNumber: 1, reps: 10, weight: 100, completed: false))
        let quest = completedQuest(daysAgo: 0, exercises: [ex])
        XCTAssertNil(ExerciseMetricsService.metrics(for: "Row", in: [quest]))
    }

    func testIgnoresIncompleteQuests() {
        let quest = Quest(name: "Planned", status: .planned)
        quest.exercises.append(exercise(name: "Squat", sets: [(10, 100, .pounds)]))
        XCTAssertNil(ExerciseMetricsService.metrics(for: "Squat", in: [quest]))
    }

    func testCombinesMultipleOccurrencesInSameQuest() {
        let ex1 = exercise(name: "Bench Press", sets: [(10, 100, .pounds)])
        let ex2 = exercise(name: "Bench Press", sets: [(10, 120, .pounds)])
        let quest = completedQuest(daysAgo: 0, exercises: [ex1, ex2])
        let metrics = try! XCTUnwrap(ExerciseMetricsService.metrics(for: "Bench Press", in: [quest]))
        XCTAssertEqual(metrics.history.count, 1)
        XCTAssertEqual(metrics.history.first?.maxWeight, 120)
    }
}
