import XCTest
@testable import RepSetForge

final class QuestCalendarServiceTests: XCTestCase {

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = 1 // Sunday
        return calendar
    }

    private func completedQuest(name: String, on date: Date) -> Quest {
        let quest = Quest(name: name, date: date, status: .completed)
        quest.completedDate = date
        return quest
    }

    private func date(year: Int, month: Int, day: Int, hour: Int = 12) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        return utcCalendar.date(from: components)!
    }

    // MARK: groupedByDay

    func testGroupsMultipleQuestsOnTheSameDayTogether() {
        let morning = completedQuest(name: "Morning Lift", on: date(year: 2026, month: 3, day: 10, hour: 7))
        let evening = completedQuest(name: "Evening Cardio", on: date(year: 2026, month: 3, day: 10, hour: 20))
        let otherDay = completedQuest(name: "Leg Day", on: date(year: 2026, month: 3, day: 11))

        let grouped = QuestCalendarService.groupedByDay([morning, evening, otherDay], calendar: utcCalendar)
        let key = utcCalendar.startOfDay(for: date(year: 2026, month: 3, day: 10))

        XCTAssertEqual(grouped[key]?.count, 2)
        XCTAssertEqual(Set(grouped[key]?.map(\.name) ?? []), ["Morning Lift", "Evening Cardio"])
    }

    func testIgnoresIncompleteQuests() {
        let planned = Quest(name: "Planned", status: .planned)
        let active = Quest(name: "Active", status: .active)
        let grouped = QuestCalendarService.groupedByDay([planned, active], calendar: utcCalendar)
        XCTAssertTrue(grouped.isEmpty)
    }

    func testEmptyInputYieldsEmptyGrouping() {
        XCTAssertTrue(QuestCalendarService.groupedByDay([], calendar: utcCalendar).isEmpty)
    }

    // MARK: monthGrid

    func testMonthGridHas42Days() {
        let grid = QuestCalendarService.monthGrid(containing: date(year: 2026, month: 3, day: 15), calendar: utcCalendar)
        XCTAssertEqual(grid.count, 42)
    }

    func testMonthGridContainsEveryDayOfTheMonth() {
        // March 2026 has 31 days.
        let grid = QuestCalendarService.monthGrid(containing: date(year: 2026, month: 3, day: 1), calendar: utcCalendar)
        let daysInMarch = grid.filter { utcCalendar.component(.month, from: $0) == 3 }
        XCTAssertEqual(daysInMarch.count, 31)
    }

    func testMonthGridStartsOnFirstWeekday() {
        let grid = QuestCalendarService.monthGrid(containing: date(year: 2026, month: 3, day: 15), calendar: utcCalendar)
        let firstDay = try! XCTUnwrap(grid.first)
        XCTAssertEqual(utcCalendar.component(.weekday, from: firstDay), utcCalendar.firstWeekday)
    }

    func testMonthGridIsConsecutiveDays() {
        let grid = QuestCalendarService.monthGrid(containing: date(year: 2026, month: 3, day: 15), calendar: utcCalendar)
        for index in 1..<grid.count {
            let expected = utcCalendar.date(byAdding: .day, value: 1, to: grid[index - 1])
            XCTAssertEqual(grid[index], expected)
        }
    }
}
