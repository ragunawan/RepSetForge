import XCTest
@testable import RepSetForge

final class TrainingStyleServiceTests: XCTestCase {

    func testNoXPAnywhereYieldsFreshRecruit() {
        let muscles = MuscleGroup.allCases.map { MuscleProgress(muscleGroup: $0) }
        XCTAssertEqual(TrainingStyleService.style(for: muscles), .freshRecruit)
    }

    func testEmptyMusclesYieldsFreshRecruit() {
        XCTAssertEqual(TrainingStyleService.style(for: []), .freshRecruit)
    }

    func testDominantChestXPYieldsBrawler() {
        var muscles = MuscleGroup.allCases.map { MuscleProgress(muscleGroup: $0, totalXP: 10) }
        muscles[MuscleGroup.allCases.firstIndex(of: .chest)!].totalXP = 500

        XCTAssertEqual(TrainingStyleService.style(for: muscles), .brawler)
    }

    func testDominantCardioXPYieldsMarathoner() {
        var muscles = MuscleGroup.allCases.map { MuscleProgress(muscleGroup: $0, totalXP: 10) }
        muscles[MuscleGroup.allCases.firstIndex(of: .cardio)!].totalXP = 500

        XCTAssertEqual(TrainingStyleService.style(for: muscles), .marathoner)
    }

    func testEachMuscleGroupMapsToItsOwnStyle() {
        let expected: [MuscleGroup: TrainingStyle] = [
            .chest: .brawler, .back: .anchor, .legs: .powerhouse,
            .shoulders: .titan, .arms: .grappler, .core: .ironclad, .cardio: .marathoner
        ]
        for (dominant, style) in expected {
            var muscles = MuscleGroup.allCases.map { MuscleProgress(muscleGroup: $0, totalXP: 5) }
            muscles[MuscleGroup.allCases.firstIndex(of: dominant)!].totalXP = 1000
            XCTAssertEqual(TrainingStyleService.style(for: muscles), style, "\(dominant) should map to \(style)")
        }
    }

    func testEvenlySpreadXPYieldsAllRounder() {
        let muscles = MuscleGroup.allCases.map { MuscleProgress(muscleGroup: $0, totalXP: 100) }
        XCTAssertEqual(TrainingStyleService.style(for: muscles), .allRounder)
    }

    func testJustBelowDominanceThresholdYieldsAllRounder() {
        // 7 muscle groups; give one exactly a hair under the 35% dominance threshold.
        var muscles = MuscleGroup.allCases.map { MuscleProgress(muscleGroup: $0, totalXP: 100) }
        let total = 700.0
        muscles[0].totalXP = Int(total * 0.34) // 238, below the 35% cutoff
        let remainingTotal = 700 - muscles[0].totalXP
        for index in 1..<muscles.count {
            muscles[index].totalXP = remainingTotal / (muscles.count - 1)
        }

        XCTAssertEqual(TrainingStyleService.style(for: muscles), .allRounder)
    }
}
