import XCTest

final class ForgeUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testAppLaunches() {
        // Phase 1: stub UI should show "Forge" text
        XCTAssertTrue(app.staticTexts["Forge"].exists, "App should launch and show placeholder text")
    }
}
