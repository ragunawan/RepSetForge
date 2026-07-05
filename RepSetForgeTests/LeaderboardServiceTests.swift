import XCTest
@testable import RepSetForge

final class LeaderboardServiceTests: XCTestCase {
    private func entry(id: String, level: Int = 1) -> LeaderboardService.Entry {
        LeaderboardService.Entry(
            id: id,
            displayName: "Player \(id)",
            level: level,
            totalXP: 0,
            streakDays: 0,
            completedQuestCount: 0
        )
    }

    func testRankReturnsOneBasedPosition() {
        let entries = [entry(id: "a"), entry(id: "b"), entry(id: "c")]
        XCTAssertEqual(LeaderboardService.rank(of: "a", in: entries), 1)
        XCTAssertEqual(LeaderboardService.rank(of: "b", in: entries), 2)
        XCTAssertEqual(LeaderboardService.rank(of: "c", in: entries), 3)
    }

    func testRankReturnsNilWhenEntryIsNotInTheList() {
        let entries = [entry(id: "a"), entry(id: "b")]
        XCTAssertNil(LeaderboardService.rank(of: "not-there", in: entries))
    }

    func testRankOnEmptyListIsNil() {
        XCTAssertNil(LeaderboardService.rank(of: "a", in: []))
    }
}
