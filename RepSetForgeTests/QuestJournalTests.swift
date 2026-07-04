import XCTest
@testable import RepSetForge

final class QuestJournalTests: XCTestCase {

    func testNewQuestHasNoNotesOrPerceivedEffortByDefault() {
        let quest = Quest(name: "Leg Day")
        XCTAssertEqual(quest.notes, "")
        XCTAssertNil(quest.perceivedEffort)
    }

    func testQuestNotesAndPerceivedEffortRoundTrip() {
        let quest = Quest(name: "Leg Day")
        quest.notes = "Felt strong today, bumped up squat weight."
        quest.perceivedEffort = 8
        XCTAssertEqual(quest.notes, "Felt strong today, bumped up squat weight.")
        XCTAssertEqual(quest.perceivedEffort, 8)
    }

    func testNewExerciseHasNoPerceivedEffortByDefault() {
        let exercise = Exercise(name: "Squat", primaryMuscle: .legs)
        XCTAssertNil(exercise.perceivedEffort)
    }

    func testExercisePerceivedEffortRoundTrips() {
        let exercise = Exercise(name: "Squat", primaryMuscle: .legs)
        exercise.perceivedEffort = 6
        XCTAssertEqual(exercise.perceivedEffort, 6)
    }

    func testDuplicationDoesNotCarryOverJournalFields() {
        let original = Quest(name: "Leg Day", status: .completed)
        original.notes = "Knee felt a bit tight."
        original.perceivedEffort = 9
        let exercise = Exercise(name: "Squat", primaryMuscle: .legs)
        exercise.perceivedEffort = 7
        original.exercises.append(exercise)

        let copy = QuestDuplicationService.duplicate(original)

        XCTAssertEqual(copy.notes, "")
        XCTAssertNil(copy.perceivedEffort)
        XCTAssertNil(copy.exercises.first?.perceivedEffort)
    }
}
