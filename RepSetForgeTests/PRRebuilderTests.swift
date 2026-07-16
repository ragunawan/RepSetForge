import XCTest
@testable import RepSetForge

final class PRRebuilderTests: XCTestCase {
  func testRebuildCreatesRecordsFromSetHistoryAndMarksWinningSets() {
    let exercise = Exercise(name: "Back Squat")
    let base = Date(timeIntervalSince1970: 1_000)
    let oldSet = SetEntry(index: 1, weightKg: 100, reps: 5, completedAt: base)
    let bestWeight = SetEntry(index: 2, weightKg: 120, reps: 3, completedAt: base.addingTimeInterval(60))
    let bestE1RMAndVolume = SetEntry(index: 3, weightKg: 110, reps: 10, completedAt: base.addingTimeInterval(120))
    let warmup = SetEntry(index: 4, type: .warmup, weightKg: 130, reps: 1, completedAt: base.addingTimeInterval(180))

    let records = PRRebuilder.rebuild(for: exercise, sets: [oldSet, bestWeight, bestE1RMAndVolume, warmup])

    XCTAssertTrue(records.contains { $0.kind == .bestWeight && $0.set === bestWeight })
    XCTAssertTrue(records.contains { $0.kind == .bestE1RM && $0.set === bestE1RMAndVolume })
    XCTAssertTrue(records.contains { $0.kind == .bestVolume && $0.set === bestE1RMAndVolume })
    XCTAssertEqual(records.filter { $0.kind == .repsAtWeight }.count, 3)
    XCTAssertTrue(bestWeight.isPR)
    XCTAssertTrue(bestE1RMAndVolume.isPR)
    XCTAssertFalse(warmup.isPR)
  }

  func testRebuildClearsStalePRFlagsBeforeRecomputing() {
    let exercise = Exercise(name: "Deadlift")
    let base = Date(timeIntervalSince1970: 1_000)
    let stale = SetEntry(index: 1, type: .warmup, weightKg: 100, reps: 5, completedAt: base, isPR: true)
    let winner = SetEntry(index: 2, weightKg: 100, reps: 8, completedAt: base.addingTimeInterval(60))

    _ = PRRebuilder.rebuild(for: exercise, sets: [stale, winner])

    XCTAssertFalse(stale.isPR)
    XCTAssertTrue(winner.isPR)
  }
}
