import XCTest
@testable import RepSetForge

final class GhostResolverTests: XCTestCase {
    typealias RV = GhostResolver.RowValues

    func testFirstRowInheritsFromPreviousSession() {
        let out = GhostResolver.resolve(
            rows: [RV()], touched: [false],
            previous: [RV(weightKg: 100, reps: 8, rpe: 8)])
        XCTAssertEqual(out[0].values, RV(weightKg: 100, reps: 8, rpe: 8))
        XCTAssertTrue(out[0].isGhost)
    }

    func testLaterRowInheritsFromRowAbove() {
        let out = GhostResolver.resolve(
            rows: [RV(weightKg: 102.5, reps: 8, rpe: 8), RV()],
            touched: [true, false],
            previous: [RV(weightKg: 100, reps: 8, rpe: 8)])
        XCTAssertEqual(out[1].values.weightKg, 102.5) // row above wins over prev session
        XCTAssertTrue(out[1].isGhost)
    }

    func testTouchedRowIsNeverGhost() {
        let out = GhostResolver.resolve(
            rows: [RV(weightKg: 80, reps: 10, rpe: nil)],
            touched: [true],
            previous: [RV(weightKg: 100, reps: 8, rpe: 8)])
        XCTAssertFalse(out[0].isGhost)
        XCTAssertNil(out[0].values.rpe) // touched rows keep their own gaps
    }

    func testPartialInheritanceFillsOnlyMissingFields() {
        let out = GhostResolver.resolve(
            rows: [RV(weightKg: 100, reps: 8, rpe: 8), RV(weightKg: 90)],
            touched: [true, false],
            previous: [])
        XCTAssertEqual(out[1].values.weightKg, 90) // own value kept
        XCTAssertEqual(out[1].values.reps, 8)      // inherited
        XCTAssertTrue(out[1].isGhost)
    }

    func testChainedInheritanceThroughGhostRows() {
        let out = GhostResolver.resolve(
            rows: [RV(), RV(), RV()],
            touched: [false, false, false],
            previous: [RV(weightKg: 100, reps: 8, rpe: nil)])
        // Row 0 pulls prev session; rows 1–2 chain from resolved row above.
        XCTAssertEqual(out[2].values.weightKg, 100)
        XCTAssertEqual(out[2].values.reps, 8)
    }

    func testNoSourcesMeansEmptyNonGhost() {
        let out = GhostResolver.resolve(rows: [RV()], touched: [false], previous: [])
        XCTAssertNil(out[0].values.weightKg)
        XCTAssertFalse(out[0].isGhost) // nothing inherited → not ghost-styled
    }
}
