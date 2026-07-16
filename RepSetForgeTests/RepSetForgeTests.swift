import XCTest
@testable import RepSetForge

/// Phase 0 placeholder so the test target links. Real suites land in Phase 1
/// (e1RM, dedup, restore branching, PR rebuild).
final class RepSetForgeTests: XCTestCase {
    func testTokensGenerated() {
        XCTAssertEqual(DT.Spacing.setRowHitTarget, 44)
        XCTAssertEqual(DT.Radius.card, 10)
    }
}
