import XCTest
@testable import RepSetForge

final class StrengthMathTests: XCTestCase {
    func testEpleySingleRepIsWeight() {
        XCTAssertEqual(StrengthMath.epleyE1RM(weightKg: 100, reps: 1), 100)
    }

    func testEpleyFormula() {
        // 100 × (1 + 10/30) = 133.33…
        let e1 = StrengthMath.epleyE1RM(weightKg: 100, reps: 10)!
        XCTAssertEqual(NSDecimalNumber(decimal: e1).doubleValue, 133.3333, accuracy: 0.001)
    }

    func testEpleyCapAtTwelveReps() {
        XCTAssertNotNil(StrengthMath.epleyE1RM(weightKg: 60, reps: 12))
        XCTAssertNil(StrengthMath.epleyE1RM(weightKg: 60, reps: 13))
        XCTAssertNil(StrengthMath.epleyE1RM(weightKg: 60, reps: 0))
    }

    func testCanonicalNameKey() {
        XCTAssertEqual(StrengthMath.canonicalNameKey("Bench-Press (Barbell)"), "bench press barbell")
        XCTAssertEqual(StrengthMath.canonicalNameKey("  DB  Row!! "), "db row")
        XCTAssertEqual(StrengthMath.canonicalNameKey(""), "")
    }

    func testVolume() {
        XCTAssertEqual(StrengthMath.volumeKg(weightKg: 80, reps: 5), 400)
        XCTAssertEqual(StrengthMath.volumeKg(weightKg: nil, reps: 5), 0)
    }
}
