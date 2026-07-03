import XCTest
@testable import RepSetForge

final class QuestSchedulerTests: XCTestCase {

    func testTodayIsActive() {
        XCTAssertEqual(QuestScheduler.status(for: .now), .active)
    }

    func testPastDateIsActiveForBackdating() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        XCTAssertEqual(QuestScheduler.status(for: yesterday), .active)
    }

    func testFutureDateIsPlanned() {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: .now)!
        XCTAssertEqual(QuestScheduler.status(for: tomorrow), .planned)
    }

    func testLaterTimeTodayIsStillActiveNotPlanned() {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let endOfToday = calendar.date(bySettingHour: 23, minute: 59, second: 0, of: .now)!
        XCTAssertEqual(QuestScheduler.status(for: endOfToday, calendar: calendar), .active)
    }
}
