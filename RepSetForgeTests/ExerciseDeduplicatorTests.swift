import XCTest
@testable import RepSetForge

final class ExerciseDeduplicatorTests: XCTestCase {
  func testCanonicalNameLowercasesAndStripsPunctuation() {
    XCTAssertEqual(ExerciseDeduplicator.canonicalNameKey(for: "Bench-Press!!"), "benchpress")
    XCTAssertEqual(ExerciseDeduplicator.canonicalNameKey(for: "  Incline   DB Press "), "incline db press")
  }

  func testFuzzyMatchFindsSmallEditDistance() {
    let bench = Exercise(name: "Bench Press")
    XCTAssertEqual(ExerciseDeduplicator.similarExercises(to: "Bench Pres", existing: [bench]).map(\.name), ["Bench Press"])
  }

  func testFuzzyMatchFindsTokenSubset() {
    let romanianDeadlift = Exercise(name: "Barbell Romanian Deadlift")
    XCTAssertEqual(
      ExerciseDeduplicator.similarExercises(to: "Romanian Deadlift", existing: [romanianDeadlift]).map(\.name),
      ["Barbell Romanian Deadlift"]
    )
  }
}
