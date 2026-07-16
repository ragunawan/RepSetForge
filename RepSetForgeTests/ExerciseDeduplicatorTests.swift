import XCTest
@testable import RepSetForge

final class ExerciseDeduplicatorTests: XCTestCase {
    func testExactMatch() {
        XCTAssertTrue(ExerciseDeduplicator.isSimilar("bench press", "bench press"))
    }

    func testLevenshteinWithinTwo() {
        XCTAssertTrue(ExerciseDeduplicator.isSimilar("bench pres", "bench press"))   // 1 edit
        XCTAssertTrue(ExerciseDeduplicator.isSimilar("bench prss", "bench press"))   // 2 edits
        XCTAssertFalse(ExerciseDeduplicator.isSimilar("squat", "bench press"))
    }

    func testTokenSubset() {
        XCTAssertTrue(ExerciseDeduplicator.isSimilar("bench press", "incline bench press"))
        XCTAssertTrue(ExerciseDeduplicator.isSimilar("barbell row bent over", "barbell row"))
    }

    func testSimilarKeysFiltersAndCanonicalizes() {
        let existing = ["bench press", "back squat", "deadlift"]
        let hits = ExerciseDeduplicator.similarKeys(to: "Bench-Press!", existingKeys: existing)
        XCTAssertEqual(hits, ["bench press"])
        XCTAssertTrue(ExerciseDeduplicator.similarKeys(to: "", existingKeys: existing).isEmpty)
    }

    func testLevenshteinBasics() {
        XCTAssertEqual(ExerciseDeduplicator.levenshtein("", "abc"), 3)
        XCTAssertEqual(ExerciseDeduplicator.levenshtein("kitten", "sitting"), 3)
    }
}
