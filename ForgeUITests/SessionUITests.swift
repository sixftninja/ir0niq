import XCTest

final class SessionUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--skip-onboarding"]
        app.launch()
    }

    // MARK: - Home screen session entry points

    func testStartWorkoutButtonExists() {
        XCTAssertTrue(app.buttons["start_workout_button"].waitForExistence(timeout: 5),
                      "Start Workout button must be present on Home tab")
    }

    func testAdHocSessionButtonExists() {
        XCTAssertTrue(app.buttons["adhoc_session_button"].waitForExistence(timeout: 5),
                      "Ad-hoc Session button must be present on Home tab")
    }

    func testBothSessionEntryPointsVisible() {
        let start = app.buttons["start_workout_button"]
        let adhoc = app.buttons["adhoc_session_button"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        XCTAssertTrue(adhoc.exists)
    }

    // MARK: - Template-start path

    func testStartWorkoutOpensTemplatePicker() {
        let button = app.buttons["start_workout_button"]
        guard button.waitForExistence(timeout: 5) else {
            XCTFail("start_workout_button not found")
            return
        }
        button.tap()
        // Sheet should appear (Choose Template navigation bar or cancel button)
        XCTAssertTrue(
            app.navigationBars["Choose Template"].waitForExistence(timeout: 3) ||
            app.buttons["Cancel"].waitForExistence(timeout: 3),
            "Template picker sheet should appear after tapping Start Workout"
        )
        // Dismiss
        if app.buttons["Cancel"].exists { app.buttons["Cancel"].tap() }
    }
}
