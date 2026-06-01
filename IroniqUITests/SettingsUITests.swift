import XCTest

final class SettingsUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--skip-onboarding"]
        app.launch()
        app.buttons["profile_button"].tap()
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
        XCTAssertTrue(app.buttons["reset_onboarding_button"].waitForExistence(timeout: 3))
    }
}
