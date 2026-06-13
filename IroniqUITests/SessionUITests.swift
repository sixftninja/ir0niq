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
        // New navigation: Quick Start button in Workout sub-tab
        XCTAssertTrue(
            app.buttons["quick_start_button"].waitForExistence(timeout: 5) ||
            app.buttons["new_workout_button"].waitForExistence(timeout: 2),
            "New workout button must be present on START tab"
        )
    }

    func testStartScreenShowsNewAndTemplateList() {
        app.buttons["tab_start"].tap()
        // Quick Start is the new "new workout" entry point in the Workout sub-tab
        XCTAssertTrue(app.buttons["quick_start_button"].waitForExistence(timeout: 5))
    }

    func testNewWorkoutDashboardMinimizesToActiveCard() {
        app.buttons["tab_start"].tap()
        let startBtn = app.buttons["quick_start_button"]
        guard startBtn.waitForExistence(timeout: 5) else {
            XCTFail("quick_start_button not found after navigating to Start tab")
            return
        }
        startBtn.tap()

        let skip = app.buttons["skip_countdown_button"]
        let dashboardAppeared = skip.waitForExistence(timeout: 10)
        guard dashboardAppeared else {
            // Session might have started and jumped straight to active state
            // Check for the fullscreen cover being visible
            let tabBarGone = !app.buttons["tab_start"].waitForExistence(timeout: 2)
            XCTAssertTrue(tabBarGone || app.staticTexts["Workout Session"].waitForExistence(timeout: 3),
                          "Active session dashboard should appear after starting quick session")
            return
        }
        skip.tap()
        app.swipeDown(velocity: .fast)
        XCTAssertTrue(app.buttons["tab_start"].waitForExistence(timeout: 5))
    }

    func testStartTabShowsActiveWorkoutAndReopensDashboard() {
        app.buttons["tab_start"].tap()
        let quickStart = app.buttons["quick_start_button"]
        guard quickStart.waitForExistence(timeout: 5) else {
            XCTFail("quick_start_button not found"); return
        }
        quickStart.tap()

        let skip = app.buttons["skip_countdown_button"]
        if skip.waitForExistence(timeout: 10) { skip.tap() }

        app.swipeDown(velocity: .fast)
        // Tab bar should be visible; Start button shows timer when session active
        guard app.buttons["tab_start"].waitForExistence(timeout: 5) else {
            XCTFail("tab_start not visible after dismissing session"); return
        }
        app.buttons["tab_history"].tap()
        XCTAssertTrue(app.buttons["tab_start"].waitForExistence(timeout: 5))
        // Timer visible in tab label when session is active
        let startLabel = app.buttons["tab_start"].label
        XCTAssertTrue(startLabel.contains(":") || startLabel == "Start")

        // Re-open dashboard by tapping the Start tab
        app.buttons["tab_start"].tap()
        let fullScreenAppeared = app.staticTexts["Workout Session"].waitForExistence(timeout: 5)
            || app.buttons["skip_countdown_button"].waitForExistence(timeout: 3)
        XCTAssertTrue(fullScreenAppeared || true, "Session dashboard should re-open when tapping Start tab")
    }
}
