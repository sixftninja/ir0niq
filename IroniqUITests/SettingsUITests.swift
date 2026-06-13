import XCTest

final class SettingsUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--skip-onboarding"]
        app.launch()
        let profileBtn = app.buttons["profile_button"]
        XCTAssertTrue(profileBtn.waitForExistence(timeout: 5))
        profileBtn.tap()
        // Wait for settings sheet to appear
        _ = app.navigationBars["Settings"].waitForExistence(timeout: 3)
    }

    func testSettingsViewLoads() {
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))
    }

    func testUnitPickerExists() {
        // SwiftUI Picker renders as a cell with the label "Units"
        XCTAssertTrue(app.staticTexts["Units"].waitForExistence(timeout: 3) ||
                      app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Units'")).firstMatch.waitForExistence(timeout: 1))
    }

    func testResetOnboardingButtonExists() {
        let btn = app.buttons["reset_onboarding_button"]
        if !btn.waitForExistence(timeout: 2) {
            // Scroll down to find it
            app.swipeUp()
            app.swipeUp()
        }
        XCTAssertTrue(btn.waitForExistence(timeout: 3))
    }
}
