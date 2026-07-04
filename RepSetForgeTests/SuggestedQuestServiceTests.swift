import XCTest
@testable import RepSetForge

final class SuggestedQuestServiceTests: XCTestCase {

    private func completedQuest(name: String, daysAgo: Int, exerciseNames: [String] = ["Bench Press"]) -> Quest {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now)!
        let quest = Quest(name: name, date: date, status: .completed)
        quest.completedDate = date
        for exerciseName in exerciseNames {
            let exercise = Exercise(name: exerciseName, primaryMuscle: .chest)
            exercise.sets.append(ExerciseSet(setNumber: 1, reps: 8, weight: 135, weightUnit: .pounds))
            quest.exercises.append(exercise)
        }
        return quest
    }

    func testNoSuggestionWithNoHistory() {
        XCTAssertNil(SuggestedQuestService.suggestedQuest(from: []))
    }

    func testNoSuggestionWhenEveryQuestNameIsUnique() {
        let quests = [
            completedQuest(name: "Push Day", daysAgo: 1),
            completedQuest(name: "Pull Day", daysAgo: 2),
            completedQuest(name: "Leg Day", daysAgo: 3),
        ]
        XCTAssertNil(SuggestedQuestService.suggestedQuest(from: quests))
    }

    func testNoSuggestionForSingleQuest() {
        let quests = [completedQuest(name: "Push Day", daysAgo: 1)]
        XCTAssertNil(SuggestedQuestService.suggestedQuest(from: quests))
    }

    func testSuggestsRepeatedRoutineDueSoonest() {
        // "Push Day" repeated, last done 5 days ago. "Leg Day" repeated, last done 1 day ago.
        // Push Day is more overdue, so it should be suggested.
        let quests = [
            completedQuest(name: "Push Day", daysAgo: 12),
            completedQuest(name: "Push Day", daysAgo: 5),
            completedQuest(name: "Leg Day", daysAgo: 8),
            completedQuest(name: "Leg Day", daysAgo: 1),
        ]
        let suggestion = try! XCTUnwrap(SuggestedQuestService.suggestedQuest(from: quests))
        XCTAssertEqual(suggestion.name, "Push Day")
        XCTAssertEqual(suggestion.timesRepeated, 2)
    }

    func testSuggestionSnapshotsExercisesFromMostRecentOccurrence() {
        let older = completedQuest(name: "Push Day", daysAgo: 10, exerciseNames: ["Old Bench"])
        let newer = completedQuest(name: "Push Day", daysAgo: 3, exerciseNames: ["New Bench", "Overhead Press"])
        let suggestion = try! XCTUnwrap(SuggestedQuestService.suggestedQuest(from: [older, newer]))
        XCTAssertEqual(suggestion.exerciseBlueprints.map(\.name), ["New Bench", "Overhead Press"])
    }

    func testIgnoresQuestsOutsideLookbackWindow() {
        let quests = [
            completedQuest(name: "Push Day", daysAgo: 40),
            completedQuest(name: "Push Day", daysAgo: 35),
        ]
        XCTAssertNil(SuggestedQuestService.suggestedQuest(from: quests, lookbackDays: 30))
    }

    func testIgnoresIncompleteQuests() {
        let planned = Quest(name: "Push Day", status: .planned)
        let active = Quest(name: "Push Day", status: .active)
        XCTAssertNil(SuggestedQuestService.suggestedQuest(from: [planned, active]))
    }

    func testMakeQuestBuildsActiveQuestFromSuggestion() {
        let quests = [
            completedQuest(name: "Push Day", daysAgo: 10),
            completedQuest(name: "Push Day", daysAgo: 3),
        ]
        let suggestion = try! XCTUnwrap(SuggestedQuestService.suggestedQuest(from: quests))
        let newQuest = SuggestedQuestService.makeQuest(from: suggestion, unit: .kilograms)

        XCTAssertEqual(newQuest.name, "Push Day")
        XCTAssertEqual(newQuest.status, .active)
        XCTAssertEqual(newQuest.exercises.count, 1)
        XCTAssertEqual(newQuest.exercises.first?.sets.first?.weightUnit, .kilograms)
    }
}
