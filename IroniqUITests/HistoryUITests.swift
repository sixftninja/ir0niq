import XCTest

final class HistoryUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--skip-onboarding"]
        app.launch()
        app.buttons["tab_history"].tap()
    }

    func testHistoryViewLoads() {
        // History no longer has a navigation bar title — check the segment control loads instead
        XCTAssertTrue(
            app.segmentedControls["history_view_picker"].waitForExistence(timeout: 5) ||
            app.staticTexts["No Sessions"].waitForExistence(timeout: 3)
        )
    }

    func testHistoryViewPickerExists() {
        XCTAssertTrue(app.segmentedControls["history_view_picker"].waitForExistence(timeout: 3))
    }

    func testCalendarViewOpens() {
        let picker = app.segmentedControls["history_view_picker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 3))
        picker.buttons["Calendar"].tap()
        XCTAssertTrue(app.staticTexts["Tap a day to see workouts."].waitForExistence(timeout: 2))
    }
}
