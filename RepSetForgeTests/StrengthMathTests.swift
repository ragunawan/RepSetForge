import XCTest
@testable import RepSetForge

final class StrengthMathTests: XCTestCase {
  func testEpleyEstimatedOneRepMaxAllowsRepsThroughTwelve() {
    XCTAssertEqual(StrengthMath.estimatedOneRepMax(weightKg: 100, reps: 6), 120)
    XCTAssertEqual(StrengthMath.estimatedOneRepMax(weightKg: 90, reps: 12), 126)
  }

  func testEpleyEstimatedOneRepMaxRejectsInvalidInputs() {
    XCTAssertNil(StrengthMath.estimatedOneRepMax(weightKg: 100, reps: 13))
    XCTAssertNil(StrengthMath.estimatedOneRepMax(weightKg: 100, reps: 0))
    XCTAssertNil(StrengthMath.estimatedOneRepMax(weightKg: nil, reps: 8))
  }
}
