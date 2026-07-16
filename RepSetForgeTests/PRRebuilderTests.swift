import XCTest
@testable import RepSetForge

final class PRRebuilderTests: XCTestCase {
    func snap(_ id: UUID = UUID(), type: SetType = .working, w: Decimal?, r: Int?,
              at: TimeInterval) -> PRRebuilder.SetSnapshot {
        .init(id: id, type: type, weightKg: w, reps: r,
              completedAt: Date(timeIntervalSince1970: at))
    }

    func testRebuildFromFixtureHistory() {
        let s1 = snap(w: 100, r: 5, at: 1)   // first working set: all PRs
        let s2 = snap(w: 110, r: 3, at: 2)   // new bestWeight; e1RM 121 < 116.67? no: > → PR
        let s3 = snap(w: 100, r: 8, at: 3)   // repsAtWeight(100) 5→8, e1RM 126.67 → PR
        let s4 = snap(w: 90, r: 5, at: 4)    // no PR (new weight bucket first-seen, not a PR)
        let result = PRRebuilder.rebuild(history: [s3, s1, s4, s2])  // order-independent

        XCTAssertEqual(result.prSetIDs, [s1.id, s2.id, s3.id])
        let best = { (k: PRKind) in result.records.first { $0.kind == k } }
        XCTAssertEqual(best(.bestWeight)?.value, 110)
        XCTAssertEqual(best(.bestWeight)?.setID, s2.id)
        XCTAssertEqual(best(.bestVolume)?.value, 800)   // 100×8
        XCTAssertEqual(best(.bestVolume)?.setID, s3.id)
        // bestE1RM = 100×(1+8/30) = 126.67 from s3
        XCTAssertEqual(best(.bestE1RM)?.setID, s3.id)
        // repsAtWeight buckets: 90, 100, 110
        let raw = result.records.filter { $0.kind == .repsAtWeight }
        XCTAssertEqual(raw.count, 3)
        XCTAssertEqual(raw.first { $0.weightKg == 100 }?.value, 8)
    }

    func testWarmupsAndIncompleteSetsExcluded() {
        let warm = snap(type: .warmup, w: 200, r: 5, at: 1)
        let noTime = PRRebuilder.SetSnapshot(id: UUID(), type: .working, weightKg: 100, reps: 5, completedAt: nil)
        let work = snap(w: 80, r: 5, at: 2)
        let result = PRRebuilder.rebuild(history: [warm, noTime, work])
        XCTAssertEqual(result.records.first { $0.kind == .bestWeight }?.value, 80)
        XCTAssertEqual(result.prSetIDs, [work.id])
    }

    func testDerivedStateFullyRegenerable() {
        // Deleting the top set and rebuilding regresses records — nothing sticky.
        let s1 = snap(w: 100, r: 5, at: 1)
        let s2 = snap(w: 120, r: 5, at: 2)
        let full = PRRebuilder.rebuild(history: [s1, s2])
        XCTAssertEqual(full.records.first { $0.kind == .bestWeight }?.value, 120)
        let edited = PRRebuilder.rebuild(history: [s1])
        XCTAssertEqual(edited.records.first { $0.kind == .bestWeight }?.value, 100)
        XCTAssertEqual(edited.prSetIDs, [s1.id])
    }

    func testHighRepSetStillCountsForVolumeButNotE1RM() {
        let s = snap(w: 50, r: 20, at: 1)  // reps > 12: no e1RM
        let result = PRRebuilder.rebuild(history: [s])
        XCTAssertNil(result.records.first { $0.kind == .bestE1RM })
        XCTAssertEqual(result.records.first { $0.kind == .bestVolume }?.value, 1000)
    }
}
