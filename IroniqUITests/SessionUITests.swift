import XCTest

final class SessionUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--skip-onboarding"]
        app.launch()
    }

    // MARK: - START screen session entry points

    func testStartTabExists() {
        XCTAssertTrue(app.buttons["tab_start"].waitForExistence(timeout: 5),
                      "START tab must be present")
    }

    func testNewWorkoutButtonExists() {
        app.buttons["tab_start"].tap()
        XCTAssertTrue(app.buttons["new_workout_button"].waitForExistence(timeout: 5),
                      "New workout button must be present on START tab")
    }

    func testStartScreenShowsNewAndTemplateList() {
        app.buttons["tab_start"].tap()
        XCTAssertTrue(app.buttons["new_workout_button"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Templates"].waitForExistence(timeout: 5))
    }

    func testNewWorkoutDashboardMinimizesToActiveCard() {
        app.buttons["tab_start"].tap()
        app.buttons["new_workout_button"].tap()

        let skip = app.buttons["skip_countdown_button"]
        let activeTitle = app.staticTexts["workout_active_title"]
        XCTAssertTrue(
            skip.waitForExistence(timeout: 8) || activeTitle.waitForExistence(timeout: 3),
            "Dashboard countdown or active workout screen should appear"
        )
        if skip.exists {
            skip.tap()
        }

        XCTAssertTrue(activeTitle.waitForExistence(timeout: 5))
        app.swipeDown()

        XCTAssertTrue(app.buttons["active_workout_card"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["active_add_exercise_button"].exists)
        XCTAssertTrue(app.buttons["active_end_workout_button"].exists)
    }

    func testStartTabShowsActiveWorkoutAndReopensDashboard() {
        app.buttons["tab_start"].tap()
        app.buttons["new_workout_button"].tap()

        let skip = app.buttons["skip_countdown_button"]
        let activeTitle = app.staticTexts["workout_active_title"]
        XCTAssertTrue(skip.waitForExistence(timeout: 8) || activeTitle.waitForExistence(timeout: 3))
        if skip.exists { skip.tap() }
        XCTAssertTrue(activeTitle.waitForExistence(timeout: 5))

        app.swipeDown()
        XCTAssertTrue(app.buttons["active_workout_card"].waitForExistence(timeout: 5))
        app.buttons["tab_history"].tap()
        XCTAssertTrue(app.buttons["tab_start"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["tab_start"].label.contains(":"))

        app.buttons["tab_start"].tap()
        XCTAssertTrue(activeTitle.waitForExistence(timeout: 5))
    }
}
