import XCTest

final class TemplateUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--skip-onboarding"]
        app.launch()
        app.tabBars.buttons["Templates"].tap()
    }

    func testNewTemplateButtonExists() {
        XCTAssertTrue(app.buttons["new_template_button"].exists)
    }

    func testOpenTemplateEditorAndCancel() {
        app.buttons["new_template_button"].tap()
        XCTAssertTrue(app.textFields["template_name_field"].exists ||
                      app.navigationBars.firstMatch.exists)
        app.buttons["Cancel"].tap()
    }

    func testTemplateEditorHasNameField() {
        app.buttons["new_template_button"].tap()
        let nameField = app.textFields["template_name_field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
    }
}
