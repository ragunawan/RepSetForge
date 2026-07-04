import XCTest
@testable import RepSetForge

final class TrainingInsightsServiceTests: XCTestCase {

    private func muscles(chest: Int = 0, back: Int = 0, legs: Int = 0, shoulders: Int = 0, arms: Int = 0, core: Int = 0, cardio: Int = 0) -> [MuscleProgress] {
        [
            MuscleProgress(muscleGroup: .chest, totalXP: chest),
            MuscleProgress(muscleGroup: .back, totalXP: back),
            MuscleProgress(muscleGroup: .legs, totalXP: legs),
            MuscleProgress(muscleGroup: .shoulders, totalXP: shoulders),
            MuscleProgress(muscleGroup: .arms, totalXP: arms),
            MuscleProgress(muscleGroup: .core, totalXP: core),
            MuscleProgress(muscleGroup: .cardio, totalXP: cardio),
        ]
    }

    func testNoInsightsWithZeroXPEverywhere() {
        let insights = TrainingInsightsService.insights(for: muscles())
        XCTAssertTrue(insights.isEmpty)
    }

    func testNoInsightsForEmptyMuscleList() {
        XCTAssertTrue(TrainingInsightsService.insights(for: []).isEmpty)
    }

    func testPushHeavyTrainingIsFlagged() {
        let insights = TrainingInsightsService.insights(for: muscles(chest: 500, back: 10, shoulders: 400))
        let balance = try! XCTUnwrap(insights.first { $0.title == "Push/Pull Balance" })
        XCTAssertTrue(balance.detail.contains("Push-heavy"))
    }

    func testPullHeavyTrainingIsFlagged() {
        let insights = TrainingInsightsService.insights(for: muscles(chest: 10, back: 500))
        let balance = try! XCTUnwrap(insights.first { $0.title == "Push/Pull Balance" })
        XCTAssertTrue(balance.detail.contains("Pull-heavy"))
    }

    func testBalancedPushPullReadsAsWellBalanced() {
        let insights = TrainingInsightsService.insights(for: muscles(chest: 100, back: 100, shoulders: 50))
        let balance = try! XCTUnwrap(insights.first { $0.title == "Push/Pull Balance" })
        XCTAssertTrue(balance.detail.contains("Well balanced"))
    }

    func testArmsXPSplitsEvenlyBetweenPushAndPull() {
        // Arms alone, evenly split 50/50 push/pull -> balanced regardless of magnitude.
        let insights = TrainingInsightsService.insights(for: muscles(arms: 1000))
        let balance = try! XCTUnwrap(insights.first { $0.title == "Push/Pull Balance" })
        XCTAssertTrue(balance.detail.contains("Well balanced"))
    }

    func testNeglectedMuscleGroupIsFlaggedWhenFarBelowAverage() {
        let insights = TrainingInsightsService.insights(for: muscles(chest: 500, back: 500, legs: 500, shoulders: 500, arms: 500, core: 500, cardio: 0))
        let neglected = try! XCTUnwrap(insights.first { $0.title == "Neglected Muscle Group" })
        XCTAssertTrue(neglected.detail.contains("Cardio"))
    }

    func testNoNeglectedInsightWhenReasonablyEven() {
        let insights = TrainingInsightsService.insights(for: muscles(chest: 100, back: 90, legs: 110, shoulders: 95, arms: 105, core: 100, cardio: 100))
        XCTAssertFalse(insights.contains { $0.title == "Neglected Muscle Group" })
    }
}
