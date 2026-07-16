import XCTest
@testable import RepSetForge

final class RestLedgerTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 1_000_000)
    func at(_ s: TimeInterval) -> Date { t0.addingTimeInterval(s) }

    func testWorkPlusRestEqualsSessionAlways() {
        var ledger = RestLedger()
        // work 100s → rest 90s (skipped at 60) → work → rest running
        ledger.startRest(duration: 90, at: at(100))
        ledger.endRest(at: at(160))                 // 60s banked
        ledger.startRest(duration: 120, at: at(400)) // running
        for now in [at(50), at(130), at(200), at(450)] {
            let session = now.timeIntervalSince(t0)
            let rest = ledger.cumulativeRest(at: now)
            let work = ledger.cumulativeWork(sessionStart: t0, at: now)
            XCTAssertEqual(work + rest, session, accuracy: 0.0001,
                           "invariant broken at t=\(session)")
        }
    }

    func testSkipBanksActualElapsedNotPlanned() {
        var ledger = RestLedger()
        ledger.startRest(duration: 150, at: at(0))
        ledger.endRest(at: at(45))
        XCTAssertEqual(ledger.cumulativeRest(at: at(100)), 45)
    }

    func testOvertimeKeepsAccruing() {
        var ledger = RestLedger()
        ledger.startRest(duration: 60, at: at(0))
        XCTAssertEqual(ledger.cumulativeRest(at: at(90)), 90) // 30s overtime counted
        XCTAssertEqual(ledger.remaining(at: at(90))!, -30, accuracy: 0.0001)
    }

    func testExtendMovesPlannedEnd() {
        var ledger = RestLedger()
        ledger.startRest(duration: 60, at: at(0))
        ledger.extendRest(by: 30)
        XCTAssertEqual(ledger.remaining(at: at(0))!, 90, accuracy: 0.0001)
        XCTAssertEqual(ledger.currentPlannedTotal, 90)
    }

    func testStartingNewRestEndsPrevious() {
        var ledger = RestLedger()
        ledger.startRest(duration: 60, at: at(0))
        ledger.startRest(duration: 60, at: at(20))
        ledger.endRest(at: at(50))
        XCTAssertEqual(ledger.cumulativeRest(at: at(50)), 50) // 20 + 30, no overlap
        XCTAssertFalse(ledger.isResting)
    }
}
