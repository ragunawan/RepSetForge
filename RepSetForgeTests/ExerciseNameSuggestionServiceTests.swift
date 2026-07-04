import XCTest
@testable import RepSetForge

final class ExerciseNameSuggestionServiceTests: XCTestCase {

    func testEmptyQueryYieldsNoSuggestions() {
        let suggestions = ExerciseNameSuggestionService.suggestions(matching: "", exerciseNames: ["Bench Press"])
        XCTAssertTrue(suggestions.isEmpty)
    }

    func testEmptyHistoryYieldsNoSuggestions() {
        let suggestions = ExerciseNameSuggestionService.suggestions(matching: "Bench", exerciseNames: [])
        XCTAssertTrue(suggestions.isEmpty)
    }

    func testMatchesCaseInsensitiveSubstring() {
        let suggestions = ExerciseNameSuggestionService.suggestions(matching: "bench", exerciseNames: ["Bench Press", "Incline Bench Press", "Squat"])
        XCTAssertEqual(Set(suggestions), ["Bench Press", "Incline Bench Press"])
    }

    func testExactMatchIsExcluded() {
        let suggestions = ExerciseNameSuggestionService.suggestions(matching: "Bench Press", exerciseNames: ["Bench Press", "Incline Bench Press"])
        XCTAssertEqual(suggestions, ["Incline Bench Press"])
    }

    func testExactMatchIsExcludedCaseInsensitively() {
        let suggestions = ExerciseNameSuggestionService.suggestions(matching: "bench press", exerciseNames: ["Bench Press"])
        XCTAssertTrue(suggestions.isEmpty)
    }

    func testDeduplicatesCaseInsensitiveVariants() {
        let suggestions = ExerciseNameSuggestionService.suggestions(matching: "bench", exerciseNames: ["bench press", "Bench Press", "BENCH PRESS"])
        XCTAssertEqual(suggestions.count, 1)
    }

    func testPrefixMatchesRankAboveMidStringMatches() {
        let suggestions = ExerciseNameSuggestionService.suggestions(matching: "press", exerciseNames: ["Bench Press", "Press Up"])
        XCTAssertEqual(suggestions.first, "Press Up")
    }

    func testMoreFrequentlyLoggedNameRanksFirstAmongEqualPrefixMatches() {
        let names = ["Bench Press", "Bench Press", "Bench Press", "Bench Row"]
        let suggestions = ExerciseNameSuggestionService.suggestions(matching: "Bench", exerciseNames: names)
        XCTAssertEqual(suggestions.first, "Bench Press")
    }

    func testRespectsLimit() {
        let names = (0..<10).map { "Exercise \($0)" }
        let suggestions = ExerciseNameSuggestionService.suggestions(matching: "Exercise", exerciseNames: names, limit: 3)
        XCTAssertEqual(suggestions.count, 3)
    }

    func testIgnoresBlankNames() {
        let suggestions = ExerciseNameSuggestionService.suggestions(matching: "bench", exerciseNames: ["", "   ", "Bench Press"])
        XCTAssertEqual(suggestions, ["Bench Press"])
    }
}
