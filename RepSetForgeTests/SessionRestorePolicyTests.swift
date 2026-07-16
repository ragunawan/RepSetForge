import XCTest
@testable import RepSetForge

final class SessionRestorePolicyTests: XCTestCase {
  func testRecentUnfinishedSessionSilentlyResumes() {
    let now = Date(timeIntervalSince1970: 10_000)
    let session = WorkoutSession(name: "Push Day A", startedAt: now.addingTimeInterval(-60 * 60))

    XCTAssertEqual(SessionRestorePolicy.action(for: session, now: now, calendar: .gregorianUTC), .silentResume)
  }

  func testFourHourSessionShowsRestorePrompt() {
    let now = Date(timeIntervalSince1970: 20_000)
    let session = WorkoutSession(name: "Push Day A", startedAt: now.addingTimeInterval(-4 * 60 * 60))

    XCTAssertEqual(
      SessionRestorePolicy.action(for: session, now: now, calendar: .gregorianUTC),
      .prompt(autoSuggestFinishAsIs: false, finishAsIsEndedAt: nil)
    )
  }

  func testTwelveHourSessionAutoSuggestsFinishAsIsAtLastSetTime() {
    let now = Date(timeIntervalSince1970: 100_000)
    let lastSetTime = now.addingTimeInterval(-60 * 60)
    let set = SetEntry(index: 1, weightKg: 100, reps: 5, completedAt: lastSetTime)
    let sessionExercise = SessionExercise(order: 0, sets: [set])
    let session = WorkoutSession(name: "Push Day A", startedAt: now.addingTimeInterval(-12 * 60 * 60), exercises: [sessionExercise])

    XCTAssertEqual(
      SessionRestorePolicy.action(for: session, now: now, calendar: .gregorianUTC),
      .prompt(autoSuggestFinishAsIs: true, finishAsIsEndedAt: lastSetTime)
    )
  }

  func testCrossingMidnightAutoSuggestsFinishAsIs() {
    let calendar = Calendar.gregorianUTC
    let start = calendar.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: 23, minute: 30))!
    let now = calendar.date(from: DateComponents(year: 2026, month: 7, day: 16, hour: 0, minute: 30))!
    let session = WorkoutSession(name: "Late Lift", startedAt: start)

    XCTAssertEqual(
      SessionRestorePolicy.action(for: session, now: now, calendar: calendar),
      .prompt(autoSuggestFinishAsIs: true, finishAsIsEndedAt: nil)
    )
  }
}

private extension Calendar {
  static var gregorianUTC: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar
  }
}
