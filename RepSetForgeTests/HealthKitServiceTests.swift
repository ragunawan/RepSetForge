import XCTest
@testable import RepSetForge

final class HealthKitServiceTests: XCTestCase {

    // MARK: estimatedActiveEnergyKilocalories

    func testEstimatedActiveEnergyScalesWithDuration() {
        let oneHour = HealthKitService.estimatedActiveEnergyKilocalories(durationSeconds: 3600, bodyWeightKilograms: 70)
        let twoHours = HealthKitService.estimatedActiveEnergyKilocalories(durationSeconds: 7200, bodyWeightKilograms: 70)
        XCTAssertEqual(twoHours, oneHour * 2, accuracy: 0.001)
    }

    func testEstimatedActiveEnergyScalesWithBodyWeight() {
        let lighter = HealthKitService.estimatedActiveEnergyKilocalories(durationSeconds: 3600, bodyWeightKilograms: 70)
        let heavier = HealthKitService.estimatedActiveEnergyKilocalories(durationSeconds: 3600, bodyWeightKilograms: 140)
        XCTAssertEqual(heavier, lighter * 2, accuracy: 0.001)
    }

    func testEstimatedActiveEnergyMatchesMETFormula() {
        // kcal = MET * kg * hours = 5.0 * 70 * 1 = 350
        let energy = HealthKitService.estimatedActiveEnergyKilocalories(durationSeconds: 3600, bodyWeightKilograms: 70)
        XCTAssertEqual(energy, 350, accuracy: 0.001)
    }

    func testZeroDurationYieldsZeroEnergy() {
        let energy = HealthKitService.estimatedActiveEnergyKilocalories(durationSeconds: 0, bodyWeightKilograms: 70)
        XCTAssertEqual(energy, 0)
    }

    // MARK: workoutDateRange

    private func completedQuest(exercises: [Exercise], daysAgo: Int = 0) -> Quest {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now)!
        let quest = Quest(name: "Quest", date: date, status: .completed)
        quest.completedDate = date
        for exercise in exercises {
            quest.exercises.append(exercise)
        }
        return quest
    }

    private func exercise(completedSetCount: Int) -> Exercise {
        let exercise = Exercise(name: "Bench Press", primaryMuscle: .chest)
        for index in 0..<completedSetCount {
            exercise.sets.append(ExerciseSet(setNumber: index + 1, reps: 10, weight: 100, completed: true))
        }
        return exercise
    }

    func testNilForIncompleteQuest() {
        let quest = Quest(name: "Planned", status: .planned)
        XCTAssertNil(HealthKitService.workoutDateRange(for: quest))
    }

    func testEndDateMatchesCompletedDate() {
        let quest = completedQuest(exercises: [exercise(completedSetCount: 3)])
        let range = try! XCTUnwrap(HealthKitService.workoutDateRange(for: quest))
        XCTAssertEqual(range.end, quest.completedDate)
    }

    func testDurationScalesWithCompletedSetCount() {
        let quest = completedQuest(exercises: [exercise(completedSetCount: 4)])
        let range = try! XCTUnwrap(HealthKitService.workoutDateRange(for: quest, secondsPerSet: 60))
        XCTAssertEqual(range.end.timeIntervalSince(range.start), 240, accuracy: 0.001)
    }

    func testZeroCompletedSetsStillYieldsAtLeastOneSetOfDuration() {
        let quest = completedQuest(exercises: [exercise(completedSetCount: 0)])
        let range = try! XCTUnwrap(HealthKitService.workoutDateRange(for: quest, secondsPerSet: 60))
        XCTAssertEqual(range.end.timeIntervalSince(range.start), 60, accuracy: 0.001)
    }

    func testOnlyCountsCompletedSetsAcrossMultipleExercises() {
        let ex1 = exercise(completedSetCount: 2)
        let ex2 = exercise(completedSetCount: 3)
        let quest = completedQuest(exercises: [ex1, ex2])
        let range = try! XCTUnwrap(HealthKitService.workoutDateRange(for: quest, secondsPerSet: 60))
        XCTAssertEqual(range.end.timeIntervalSince(range.start), 300, accuracy: 0.001)
    }
}
