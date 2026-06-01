import XCTest

final class IroniqNavigationTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--skip-onboarding"]
        app.launch()
    }

    func testTabBarExists() {
        XCTAssertTrue(app.buttons["tab_templates"].exists, "Templates tab should exist")
        XCTAssertTrue(app.buttons["tab_start"].exists, "START tab should exist")
        XCTAssertTrue(app.buttons["tab_history"].exists, "History tab should exist")
        XCTAssertTrue(app.buttons["profile_button"].exists, "Profile button should exist")
    }

    func testNewTemplateEntryFromTemplates() {
        XCTAssertTrue(app.buttons["new_template_button"].waitForExistence(timeout: 3))
    }

    func testHistoryTab() {
        XCTAssertTrue(app.buttons["tab_history"].waitForExistence(timeout: 5))
        app.buttons["tab_history"].tap()
        let historyLoaded = app.navigationBars["History"].waitForExistence(timeout: 5)
            || app.staticTexts["History"].waitForExistence(timeout: 2)
        XCTAssertTrue(historyLoaded)
    }

    func testSettingsUnderProfile() {
        XCTAssertTrue(app.buttons["profile_button"].waitForExistence(timeout: 5))
        app.buttons["profile_button"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
    }
}
