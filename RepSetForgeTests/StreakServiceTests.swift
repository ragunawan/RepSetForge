import XCTest
@testable import RepSetForge

final class StreakServiceTests: XCTestCase {
    private let calendar = Calendar.current

    private func daysAgo(_ n: Int) -> Date {
        calendar.date(byAdding: .day, value: -n, to: .now)!
    }

    func testCurrentStreakLengthCountsConsecutiveDaysEndingToday() {
        let days: Set<Date> = [0, 1, 2].map { calendar.startOfDay(for: daysAgo($0)) }.reduce(into: Set()) { $0.insert($1) }
        XCTAssertEqual(StreakService.currentStreakLength(completedDays: days), 3)
    }

    func testCurrentStreakLengthStillCountsWhenTodayIsARestDay() {
        // Trained yesterday and the day before, but not yet today.
        let days: Set<Date> = [1, 2].map { calendar.startOfDay(for: daysAgo($0)) }.reduce(into: Set()) { $0.insert($1) }
        XCTAssertEqual(StreakService.currentStreakLength(completedDays: days), 2)
    }

    func testCurrentStreakLengthIsZeroWhenNeitherTodayNorYesterdayHasACompletion() {
        let days: Set<Date> = [2, 3].map { calendar.startOfDay(for: daysAgo($0)) }.reduce(into: Set()) { $0.insert($1) }
        XCTAssertEqual(StreakService.currentStreakLength(completedDays: days), 0)
    }

    func testCurrentStreakLengthIsZeroForNoCompletionsAtAll() {
        XCTAssertEqual(StreakService.currentStreakLength(completedDays: []), 0)
    }

    func testCurrentStreakLengthStopsAtTheFirstGap() {
        // Days 0, 1 trained; day 2 is a gap; day 3 trained again (shouldn't count).
        let days: Set<Date> = [0, 1, 3].map { calendar.startOfDay(for: daysAgo($0)) }.reduce(into: Set()) { $0.insert($1) }
        XCTAssertEqual(StreakService.currentStreakLength(completedDays: days), 2)
    }

    func testCompletedDaysExtractsStartOfDayFromCompletedQuestsOnly() {
        let completed = Quest(name: "Done", status: .completed)
        completed.completedDate = .now
        let planned = Quest(name: "Not Done", status: .planned)

        let days = StreakService.completedDays(from: [completed, planned])

        XCTAssertEqual(days.count, 1)
        XCTAssertEqual(days.first, calendar.startOfDay(for: .now))
    }
}
