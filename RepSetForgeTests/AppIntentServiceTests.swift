import XCTest
import SwiftData
@testable import RepSetForge

final class AppIntentServiceTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUpWithError() throws {
        let schema = Schema([Quest.self, Exercise.self, ExerciseSet.self, PlayerCharacter.self, MuscleProgress.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
    }

    // MARK: startQuest

    func testStartQuestInsertsANewActiveQuest() throws {
        let quest = AppIntentService.startQuest(context: context)
        XCTAssertEqual(quest.status, .active)
        let quests = try context.fetch(FetchDescriptor<Quest>())
        XCTAssertEqual(quests.count, 1)
    }

    // MARK: logSet

    func testLogSetThrowsWithNoActiveQuest() {
        XCTAssertThrowsError(try AppIntentService.logSet(exerciseName: "Bench Press", reps: 10, weight: 100, weightUnit: .pounds, context: context)) { error in
            XCTAssertTrue(error is AppIntentService.LogSetError)
        }
    }

    func testLogSetCreatesNewExerciseInActiveQuest() throws {
        let quest = Quest(name: "Push Day", status: .active)
        context.insert(quest)

        let result = try AppIntentService.logSet(exerciseName: "Bench Press", reps: 10, weight: 135, weightUnit: .pounds, context: context)

        XCTAssertEqual(result.questName, "Push Day")
        XCTAssertEqual(quest.exercises.count, 1)
        XCTAssertEqual(quest.exercises.first?.sets.count, 1)
        XCTAssertEqual(quest.exercises.first?.sets.first?.reps, 10)
    }

    func testLogSetAppendsToExistingExerciseInSameQuest() throws {
        let quest = Quest(name: "Push Day", status: .active)
        context.insert(quest)

        _ = try AppIntentService.logSet(exerciseName: "Bench Press", reps: 10, weight: 100, weightUnit: .pounds, context: context)
        _ = try AppIntentService.logSet(exerciseName: "bench press", reps: 8, weight: 105, weightUnit: .pounds, context: context)

        XCTAssertEqual(quest.exercises.count, 1)
        XCTAssertEqual(quest.exercises.first?.sets.count, 2)
        XCTAssertEqual(quest.exercises.first?.sets.map(\.setNumber).sorted(), [1, 2])
    }

    func testLogSetReusesHistoricalMuscleGroupForNewExercise() throws {
        let oldQuest = Quest(name: "Old Quest", status: .completed)
        let oldExercise = Exercise(name: "Squat", primaryMuscle: .legs, secondaryMuscles: [.core])
        oldQuest.exercises.append(oldExercise)
        context.insert(oldQuest)

        let activeQuest = Quest(name: "Leg Day", status: .active)
        context.insert(activeQuest)

        _ = try AppIntentService.logSet(exerciseName: "Squat", reps: 5, weight: 225, weightUnit: .pounds, context: context)

        XCTAssertEqual(activeQuest.exercises.first?.primaryMuscle, .legs)
        XCTAssertEqual(activeQuest.exercises.first?.secondaryMuscles, [.core])
    }

    func testLogSetDefaultsToChestAndStrengthForUnknownExercise() throws {
        let quest = Quest(name: "Push Day", status: .active)
        context.insert(quest)

        _ = try AppIntentService.logSet(exerciseName: "Brand New Move", reps: 10, weight: 50, weightUnit: .pounds, context: context)

        XCTAssertEqual(quest.exercises.first?.primaryMuscle, .chest)
        XCTAssertEqual(quest.exercises.first?.exerciseType, .strength)
    }

    func testLogSetPrefersPlannedOverCompletedQuest() throws {
        let completed = Quest(name: "Done", status: .completed)
        context.insert(completed)
        let planned = Quest(name: "Upcoming", status: .planned)
        context.insert(planned)

        let result = try AppIntentService.logSet(exerciseName: "Row", reps: 10, weight: 90, weightUnit: .pounds, context: context)
        XCTAssertEqual(result.questName, "Upcoming")
    }

    // MARK: currentLevelSummary

    func testCurrentLevelSummaryReflectsCharacter() throws {
        let character = PlayerCharacter(level: 7, title: "Iron Trainee")
        context.insert(character)
        let summary = AppIntentService.currentLevelSummary(context: context)
        XCTAssertEqual(summary.level, 7)
        XCTAssertEqual(summary.title, "Iron Trainee")
    }

    func testCurrentLevelSummaryDefaultsWithNoCharacter() {
        let summary = AppIntentService.currentLevelSummary(context: context)
        XCTAssertEqual(summary.level, 1)
        XCTAssertEqual(summary.title, "Novice Adventurer")
    }
}
