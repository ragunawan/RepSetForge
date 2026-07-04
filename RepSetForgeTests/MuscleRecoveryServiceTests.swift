import XCTest
@testable import RepSetForge

final class MuscleRecoveryServiceTests: XCTestCase {

    private func completedQuest(daysAgoFrom now: Date, days: Int, exercises: [Exercise], calendar: Calendar) -> Quest {
        let completedDate = calendar.date(byAdding: .day, value: -days, to: now)!
        let quest = Quest(name: "Quest", date: completedDate, status: .completed)
        quest.completedDate = completedDate
        for exercise in exercises {
            quest.exercises.append(exercise)
        }
        return quest
    }

    private func exercise(primary: MuscleGroup, secondary: [MuscleGroup] = [], reps: Int = 10, weight: Double = 100) -> Exercise {
        let exercise = Exercise(name: "Test Exercise", primaryMuscle: primary, secondaryMuscles: secondary)
        exercise.sets.append(ExerciseSet(setNumber: 1, reps: reps, weight: weight, completed: true))
        return exercise
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func now() -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 15
        components.hour = 12
        return calendar.date(from: components)!
    }

    func testAllMuscleGroupsPresentEvenWithNoHistory() {
        let stats = MuscleRecoveryService.loadStats(from: [], calendar: calendar, now: now())
        XCTAssertEqual(Set(stats.map(\.muscleGroup)), Set(MuscleGroup.allCases))
        XCTAssertTrue(stats.allSatisfy { $0.status == .untrained && $0.daysSinceLastTrained == nil })
    }

    func testTrainedTodayIsFatigued() {
        let now = now()
        let quest = completedQuest(daysAgoFrom: now, days: 0, exercises: [exercise(primary: .chest)], calendar: calendar)
        let stats = MuscleRecoveryService.loadStats(from: [quest], calendar: calendar, now: now)
        let chest = stats.first { $0.muscleGroup == .chest }!
        XCTAssertEqual(chest.daysSinceLastTrained, 0)
        XCTAssertEqual(chest.status, .fatigued)
    }

    func testTrainedTwoDaysAgoIsRecovering() {
        let now = now()
        let quest = completedQuest(daysAgoFrom: now, days: 2, exercises: [exercise(primary: .back)], calendar: calendar)
        let stats = MuscleRecoveryService.loadStats(from: [quest], calendar: calendar, now: now)
        let back = stats.first { $0.muscleGroup == .back }!
        XCTAssertEqual(back.status, .recovering)
    }

    func testTrainedFiveDaysAgoIsFresh() {
        let now = now()
        let quest = completedQuest(daysAgoFrom: now, days: 5, exercises: [exercise(primary: .legs)], calendar: calendar)
        let stats = MuscleRecoveryService.loadStats(from: [quest], calendar: calendar, now: now)
        let legs = stats.first { $0.muscleGroup == .legs }!
        XCTAssertEqual(legs.status, .fresh)
    }

    func testRecentLoadExcludesQuestsOutsideTheLookbackWindow() {
        let now = now()
        let quest = completedQuest(daysAgoFrom: now, days: 30, exercises: [exercise(primary: .arms)], calendar: calendar)
        let stats = MuscleRecoveryService.loadStats(from: [quest], calendar: calendar, now: now)
        let arms = stats.first { $0.muscleGroup == .arms }!
        XCTAssertEqual(arms.recentLoad, 0)
        // But days-since-last-trained still looks back beyond the window.
        XCTAssertEqual(arms.daysSinceLastTrained, 30)
        XCTAssertEqual(arms.status, .fresh)
    }

    func testSecondaryMuscleGetsReducedLoadShare() {
        let now = now()
        let ex = exercise(primary: .chest, secondary: [.shoulders])
        let quest = completedQuest(daysAgoFrom: now, days: 0, exercises: [ex], calendar: calendar)
        let stats = MuscleRecoveryService.loadStats(from: [quest], calendar: calendar, now: now)
        let chest = stats.first { $0.muscleGroup == .chest }!
        let shoulders = stats.first { $0.muscleGroup == .shoulders }!
        XCTAssertGreaterThan(chest.recentLoad, 0)
        XCTAssertGreaterThan(shoulders.recentLoad, 0)
        XCTAssertLessThan(shoulders.recentLoad, chest.recentLoad)
    }

    func testIgnoresIncompleteQuests() {
        let quest = Quest(name: "Planned", status: .planned)
        quest.exercises.append(exercise(primary: .core))
        let stats = MuscleRecoveryService.loadStats(from: [quest], calendar: calendar, now: now())
        let core = stats.first { $0.muscleGroup == .core }!
        XCTAssertEqual(core.status, .untrained)
    }

    func testMostRecentOccurrenceWinsWhenTrainedMultipleTimes() {
        let now = now()
        let older = completedQuest(daysAgoFrom: now, days: 10, exercises: [exercise(primary: .cardio)], calendar: calendar)
        let newer = completedQuest(daysAgoFrom: now, days: 1, exercises: [exercise(primary: .cardio)], calendar: calendar)
        let stats = MuscleRecoveryService.loadStats(from: [older, newer], calendar: calendar, now: now)
        let cardio = stats.first { $0.muscleGroup == .cardio }!
        XCTAssertEqual(cardio.daysSinceLastTrained, 1)
        XCTAssertEqual(cardio.status, .fatigued)
    }
}
