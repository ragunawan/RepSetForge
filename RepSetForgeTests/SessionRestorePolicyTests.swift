import XCTest
@testable import RepSetForge

final class SessionRestorePolicyTests: XCTestCase {
    let cal = Calendar(identifier: .gregorian)

    func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi))!
    }

    func testUnderFourHoursSameDaySilentlyResumes() {
        let start = date(2026, 7, 16, 9, 0)
        let now = date(2026, 7, 16, 12, 59)
        XCTAssertEqual(SessionRestorePolicy.action(startedAt: start, now: now, calendar: cal), .silentResume)
    }

    func testFourHoursOrMoreShowsSheet() {
        let start = date(2026, 7, 16, 9, 0)
        let now = date(2026, 7, 16, 13, 0)
        XCTAssertEqual(SessionRestorePolicy.action(startedAt: start, now: now, calendar: cal),
                       .promptSheet(suggestFinishAsIs: false))
    }

    func testOverTwelveHoursSuggestsFinishAsIs() {
        let start = date(2026, 7, 16, 1, 0)
        let now = date(2026, 7, 16, 13, 30)
        XCTAssertEqual(SessionRestorePolicy.action(startedAt: start, now: now, calendar: cal),
                       .promptSheet(suggestFinishAsIs: true))
    }

    func testMidnightCrossSuggestsFinishEvenWhenRecent() {
        let start = date(2026, 7, 16, 23, 30)
        let now = date(2026, 7, 17, 0, 30)  // only 1h old but crossed midnight
        XCTAssertEqual(SessionRestorePolicy.action(startedAt: start, now: now, calendar: cal),
                       .promptSheet(suggestFinishAsIs: true))
    }

    func testFinishAsIsEndUsesLastSetElseStart() {
        let start = date(2026, 7, 16, 9, 0)
        let last = date(2026, 7, 16, 10, 12)
        XCTAssertEqual(SessionRestorePolicy.finishAsIsEnd(startedAt: start, lastSetCompletedAt: last), last)
        XCTAssertEqual(SessionRestorePolicy.finishAsIsEnd(startedAt: start, lastSetCompletedAt: nil), start)
    }
}
