import XCTest

final class IroniqUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--skip-onboarding"]
        app.launch()
    }

    func testAppLaunches() {
        XCTAssertTrue(app.buttons["tab_templates"].waitForExistence(timeout: 5),
                      "Templates tab should appear after launch with onboarding skipped")
        XCTAssertTrue(app.buttons["tab_start"].exists,
                      "START tab should appear after launch with onboarding skipped")
    }
}
