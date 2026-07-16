import XCTest
@testable import RepSetForge

final class LadderEngineTests: XCTestCase {
    let rule = LadderEngine.Rule(repRangeLow: 8, repRangeHigh: 12,
                                 maxQualifyingRPE: 9, qualifyingSetsRequired: 2,
                                 incrementKg: 2.5)

    func day(_ n: Int) -> Date { Date(timeIntervalSince1970: Double(n) * 86_400) }

    func session(_ n: Int, _ sets: [(Decimal, Int, Double?)]) -> LadderEngine.SessionFacts {
        .init(date: day(n), sets: sets.map { .init(weightKg: $0.0, reps: $0.1, rpe: $0.2, type: .working) })
    }

    func testFreshLadderStartsAtBottomRung() {
        let state = LadderEngine.regenerate(rule: rule, startWeightKg: 100, history: [])
        XCTAssertEqual(state.levels.count, 5) // reps 8...12
        XCTAssertEqual(state.currentIndex, 0)
        XCTAssertEqual(state.current, .init(weightKg: 100, reps: 8, completedOn: nil, isLevelUp: false))
    }

    func testQualifyingSessionAdvancesOneLevel() {
        let state = LadderEngine.regenerate(rule: rule, startWeightKg: 100, history: [
            session(1, [(100, 8, 8), (100, 8, 8.5), (100, 7, 8)]),
        ])
        XCTAssertEqual(state.currentIndex, 1)
        XCTAssertEqual(state.levels[0].completedOn, day(1))
        XCTAssertEqual(state.current.reps, 9)
    }

    func testRPEAboveMaxDoesNotQualify() {
        let state = LadderEngine.regenerate(rule: rule, startWeightKg: 100, history: [
            session(1, [(100, 8, 9.5), (100, 8, 10)]),
        ])
        XCTAssertEqual(state.currentIndex, 0)
    }

    func testMissingRPEQualifies() {
        let state = LadderEngine.regenerate(rule: rule, startWeightKg: 100, history: [
            session(1, [(100, 8, nil), (100, 8, nil)]),
        ])
        XCTAssertEqual(state.currentIndex, 1)
    }

    func testBigSessionSkipsMultipleRungs() {
        // 2×(100×10 @8) qualifies rungs 8, 9 and 10 in one session.
        let state = LadderEngine.regenerate(rule: rule, startWeightKg: 100, history: [
            session(1, [(100, 10, 8), (100, 10, 8)]),
        ])
        XCTAssertEqual(state.currentIndex, 3)
        XCTAssertEqual(state.current.reps, 11)
    }

    func testTopRungCompletionLevelsUpWeight() {
        let history = (1...5).map { n in session(n, [(Decimal(100), 7 + n, Double(8)), (Decimal(100), 7 + n, Double(8))]) }
        let state = LadderEngine.regenerate(rule: rule, startWeightKg: 100, history: history)
        XCTAssertEqual(state.current.weightKg, 102.5)
        XCTAssertEqual(state.current.reps, 8)
        XCTAssertTrue(state.current.isLevelUp)
        XCTAssertEqual(state.levels.count, 10) // regenerated next block
    }

    func testPropertyRegenerableAndEditRegresses() {
        // Property (gate): state is a pure function of history — removing the
        // qualifying session regresses the ladder with no residue.
        let full = [
            session(1, [(Decimal(100), 8, Double(8)), (Decimal(100), 8, Double(8))]),
            session(2, [(Decimal(100), 9, Double(8)), (Decimal(100), 9, Double(8))]),
        ]
        let s2 = LadderEngine.regenerate(rule: rule, startWeightKg: 100, history: full)
        XCTAssertEqual(s2.currentIndex, 2)
        let edited = LadderEngine.regenerate(rule: rule, startWeightKg: 100, history: [full[0]])
        XCTAssertEqual(edited.currentIndex, 1)
        // Determinism / order independence of input array:
        let shuffled = LadderEngine.regenerate(rule: rule, startWeightKg: 100, history: full.reversed())
        XCTAssertEqual(shuffled, s2)
    }

    func testPromptEqualsLadderHead() {
        for history in [[], [session(1, [(Decimal(100), 8, Double(8)), (Decimal(100), 8, Double(8))])]] {
            let state = LadderEngine.regenerate(rule: rule, startWeightKg: 100, history: history)
            let prompt = LadderEngine.promptTarget(rule: rule, startWeightKg: 100, history: history)
            XCTAssertEqual(prompt, state.current, "prompt must be the ladder head")
        }
    }

    func testWarmupsNeverQualify() {
        let warm = LadderEngine.SessionFacts(date: day(1), sets: [
            .init(weightKg: 100, reps: 8, rpe: 7, type: .warmup),
            .init(weightKg: 100, reps: 8, rpe: 7, type: .warmup),
        ])
        let state = LadderEngine.regenerate(rule: rule, startWeightKg: 100, history: [warm])
        XCTAssertEqual(state.currentIndex, 0)
    }
}
