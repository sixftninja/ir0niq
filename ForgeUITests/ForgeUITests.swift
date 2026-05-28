import XCTest

final class ForgeUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--skip-onboarding"]
        app.launch()
    }

    func testAppLaunches() {
        // With --skip-onboarding, the tab bar should be visible
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5),
                      "Tab bar should appear after launch with onboarding skipped")
    }
}
