import XCTest
@testable import RepSetForge

final class QuestFilterServiceTests: XCTestCase {

    private func quest(name: String, status: QuestStatus = .completed, date: Date = .now, totalXP: Int = 0, exercises: [Exercise] = []) -> Quest {
        let quest = Quest(name: name, date: date, status: status)
        quest.totalXP = totalXP
        for exercise in exercises {
            quest.exercises.append(exercise)
        }
        return quest
    }

    private func exercise(name: String, primary: MuscleGroup, secondary: [MuscleGroup] = []) -> Exercise {
        Exercise(name: name, primaryMuscle: primary, secondaryMuscles: secondary)
    }

    private func date(daysFromNow: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: daysFromNow, to: .now)!
    }

    func testInactiveCriteriaIsNotActive() {
        XCTAssertFalse(QuestFilterCriteria().isActive)
    }

    func testAnySetFieldMakesCriteriaActive() {
        var criteria = QuestFilterCriteria()
        criteria.searchText = "leg"
        XCTAssertTrue(criteria.isActive)
    }

    func testSearchMatchesQuestName() {
        let questA = quest(name: "Leg Day Dungeon")
        let questB = quest(name: "Upper Body Strength")
        var criteria = QuestFilterCriteria()
        criteria.searchText = "leg"
        let results = QuestFilterService.filter([questA, questB], criteria: criteria)
        XCTAssertEqual(results.map(\.name), ["Leg Day Dungeon"])
    }

    func testSearchMatchesExerciseNameCaseInsensitively() {
        let questA = quest(name: "Push Day", exercises: [exercise(name: "Bench Press", primary: .chest)])
        let questB = quest(name: "Pull Day", exercises: [exercise(name: "Pull-Ups", primary: .back)])
        var criteria = QuestFilterCriteria()
        criteria.searchText = "BENCH"
        let results = QuestFilterService.filter([questA, questB], criteria: criteria)
        XCTAssertEqual(results.map(\.name), ["Push Day"])
    }

    func testFiltersByMuscleGroupIncludingSecondary() {
        let questA = quest(name: "A", exercises: [exercise(name: "Bench", primary: .chest, secondary: [.shoulders])])
        let questB = quest(name: "B", exercises: [exercise(name: "Squat", primary: .legs)])
        var criteria = QuestFilterCriteria()
        criteria.muscleGroup = .shoulders
        let results = QuestFilterService.filter([questA, questB], criteria: criteria)
        XCTAssertEqual(results.map(\.name), ["A"])
    }

    func testFiltersByStatus() {
        let planned = quest(name: "Planned", status: .planned)
        let completed = quest(name: "Completed", status: .completed)
        var criteria = QuestFilterCriteria()
        criteria.status = .planned
        let results = QuestFilterService.filter([planned, completed], criteria: criteria)
        XCTAssertEqual(results.map(\.name), ["Planned"])
    }

    func testFiltersByDateRange() {
        let old = quest(name: "Old", date: date(daysFromNow: -10))
        let recent = quest(name: "Recent", date: date(daysFromNow: -1))
        var criteria = QuestFilterCriteria()
        criteria.startDate = date(daysFromNow: -3)
        let results = QuestFilterService.filter([old, recent], criteria: criteria)
        XCTAssertEqual(results.map(\.name), ["Recent"])
    }

    func testFiltersByEndDate() {
        let old = quest(name: "Old", date: date(daysFromNow: -10))
        let recent = quest(name: "Recent", date: date(daysFromNow: -1))
        var criteria = QuestFilterCriteria()
        criteria.endDate = date(daysFromNow: -3)
        let results = QuestFilterService.filter([old, recent], criteria: criteria)
        XCTAssertEqual(results.map(\.name), ["Old"])
    }

    func testFiltersByXPRange() {
        let low = quest(name: "Low", totalXP: 50)
        let high = quest(name: "High", totalXP: 500)
        var criteria = QuestFilterCriteria()
        criteria.minXP = 100
        let results = QuestFilterService.filter([low, high], criteria: criteria)
        XCTAssertEqual(results.map(\.name), ["High"])
    }

    func testCombinesMultipleCriteriaWithAND() {
        let match = quest(name: "Match", status: .completed, totalXP: 200, exercises: [exercise(name: "Bench", primary: .chest)])
        let wrongStatus = quest(name: "WrongStatus", status: .planned, totalXP: 200, exercises: [exercise(name: "Bench", primary: .chest)])
        let wrongXP = quest(name: "WrongXP", status: .completed, totalXP: 10, exercises: [exercise(name: "Bench", primary: .chest)])
        var criteria = QuestFilterCriteria()
        criteria.status = .completed
        criteria.minXP = 100
        criteria.muscleGroup = .chest
        let results = QuestFilterService.filter([match, wrongStatus, wrongXP], criteria: criteria)
        XCTAssertEqual(results.map(\.name), ["Match"])
    }
}
