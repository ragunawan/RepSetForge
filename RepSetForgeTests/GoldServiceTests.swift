import XCTest
@testable import RepSetForge

final class GoldServiceTests: XCTestCase {

    func testSetGoldIsOnePerCompletedSet() {
        XCTAssertEqual(GoldService.setGold(completedSetCount: 3), 3)
        XCTAssertEqual(GoldService.setGold(completedSetCount: 0), 0)
    }

    func testQuestGoldIsTotalXPDividedByTen() {
        XCTAssertEqual(GoldService.questGold(totalXP: 250), 25)
        XCTAssertEqual(GoldService.questGold(totalXP: 9), 0) // rounds down
    }

    func testPersonalRecordGoldIsTwentyFivePerRecord() {
        XCTAssertEqual(GoldService.personalRecordGold(newRecordCount: 2), 50)
        XCTAssertEqual(GoldService.personalRecordGold(newRecordCount: 0), 0)
    }

    func testTotalGoldSumsAllThreeSources() {
        let total = GoldService.totalGold(completedSetCount: 3, questXP: 250, newRecordCount: 1)
        XCTAssertEqual(total, 3 + 25 + 25)
    }

    func testPlayerCharacterDefaultsToZeroGold() {
        let character = PlayerCharacter()
        XCTAssertEqual(character.gold, 0)
    }
}
