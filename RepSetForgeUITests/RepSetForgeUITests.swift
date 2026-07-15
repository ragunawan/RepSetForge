import XCTest

final class RepSetForgeUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// The core logging UI test (start workout → log a set → finish) is
    /// TODO.md build-order step 2 — this just verifies the tab shell launches
    /// until that flow exists.
    @MainActor
    func testAppLaunchesToHomeTab() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 5))
    }
}
