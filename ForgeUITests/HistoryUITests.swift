import XCTest

final class HistoryUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--skip-onboarding"]
        app.launch()
        app.tabBars.buttons["History"].tap()
    }

    func testHistoryViewLoads() {
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 3))
    }

    func testCalendarButtonExists() {
        XCTAssertTrue(app.buttons["calendar_button"].waitForExistence(timeout: 3))
    }

    func testCalendarViewOpens() {
        app.buttons["calendar_button"].tap()
        XCTAssertTrue(app.navigationBars["Calendar"].waitForExistence(timeout: 2))
    }
}
