import XCTest

final class ForgeNavigationTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--skip-onboarding"]
        app.launch()
    }

    func testTabBarExists() {
        // All four tabs should be present
        XCTAssertTrue(app.tabBars.buttons["Home"].exists, "Home tab should exist")
        XCTAssertTrue(app.tabBars.buttons["Templates"].exists, "Templates tab should exist")
        XCTAssertTrue(app.tabBars.buttons["History"].exists, "History tab should exist")
        XCTAssertTrue(app.tabBars.buttons["Settings"].exists, "Settings tab should exist")
    }

    func testTemplatesTab() {
        app.tabBars.buttons["Templates"].tap()
        XCTAssertTrue(app.navigationBars["Templates"].exists)
    }

    func testHistoryTab() {
        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.navigationBars["History"].exists)
    }

    func testSettingsTab() {
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].exists)
    }
}
