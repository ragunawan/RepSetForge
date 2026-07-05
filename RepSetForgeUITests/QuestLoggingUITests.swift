import XCTest

/// Drives the core quest logging loop end to end through the real UI:
/// open the current quest, log a set, and complete the quest. Uses
/// `--preview-data` (seeds three planned quests) and `--skip-onboarding`
/// (a deterministic alternative to depending on onboarding state left
/// over from a previous run) so the flow is reachable without any
/// manual setup.
final class QuestLoggingUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCoreQuestLoggingFlow() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--preview-data", "--skip-onboarding", "--tab", "0"]
        app.launch()

        let currentQuestCard = app.buttons["currentQuestCard"]
        XCTAssertTrue(currentQuestCard.waitForExistence(timeout: 10), "Dashboard should show a current quest card from --preview-data")
        currentQuestCard.tap()

        let firstExerciseRow = app.buttons["exerciseRow-Bench Press"]
        XCTAssertTrue(firstExerciseRow.waitForExistence(timeout: 10), "Quest detail should list the seeded Bench Press skill")
        firstExerciseRow.tap()

        let firstSetToggle = app.buttons["Set 1"]
        XCTAssertTrue(firstSetToggle.waitForExistence(timeout: 10), "Exercise logging should show Set 1's completion toggle")
        XCTAssertEqual(firstSetToggle.value as? String, "Not complete")
        firstSetToggle.tap()
        XCTAssertEqual(firstSetToggle.value as? String, "Complete")

        // Back to Quest Detail.
        app.navigationBars.buttons.element(boundBy: 0).tap()

        // "Complete Quest" sits in a Form section below the skills list, so
        // it's below the fold on smaller screens — the Form lazily renders
        // rows, meaning the button may not exist in the hierarchy at all
        // until scrolled into view (not just be off-screen).
        let completeQuestButton = app.buttons["Complete Quest"]
        for _ in 0..<5 where !completeQuestButton.exists {
            app.swipeUp()
        }
        XCTAssertTrue(completeQuestButton.waitForExistence(timeout: 10))
        completeQuestButton.tap()

        // Completion sheet appears; dismiss it.
        let doneButton = app.buttons["Done"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 10), "Completing a quest should show the completion summary sheet")
        doneButton.tap()

        // Dismissing the sheet returns to Quest Detail, not the Dashboard —
        // now read-only and showing the XP reward earned for the set just logged.
        XCTAssertTrue(app.staticTexts["Reward"].waitForExistence(timeout: 10))
    }

    /// The leaderboard is opt-in and off by default — confirms the
    /// opted-out empty state renders (rather than crashing or silently
    /// attempting a network fetch) on a fresh character.
    func testLeaderboardShowsOptedOutStateByDefault() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--preview-data", "--skip-onboarding", "--tab", "1"]
        app.launch()

        // "Leaderboard" is a secondary-placement toolbar item, which iOS
        // collapses into an overflow "More" menu alongside "Settings" —
        // same as "Undo Completion" elsewhere in this suite.
        let overflowButton = app.buttons["OverflowBarButtonItem"]
        XCTAssertTrue(overflowButton.waitForExistence(timeout: 10))
        overflowButton.tap()

        let leaderboardButton = app.buttons["Leaderboard"]
        XCTAssertTrue(leaderboardButton.waitForExistence(timeout: 10))
        leaderboardButton.tap()

        XCTAssertTrue(app.staticTexts["Leaderboard Opt-In Required"].waitForExistence(timeout: 10))
    }
}
