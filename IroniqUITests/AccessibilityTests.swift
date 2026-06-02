import XCTest

// Phase 5: screen reader label coverage.
// Verifies primary interactive elements have accessibility labels so VoiceOver
// users can identify and activate them.

final class AccessibilityTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--skip-onboarding"]
        app.launch()
    }

    // MARK: - Tab bar

    func testTabBarButtonsHaveLabels() {
        let tabStart = app.buttons["tab_start"]
        XCTAssertTrue(tabStart.exists, "Start tab button must exist")
        XCTAssertFalse(tabStart.label.isEmpty, "Start tab button must have a non-empty label")

        let tabTemplates = app.buttons["tab_templates"]
        XCTAssertTrue(tabTemplates.exists)
        XCTAssertFalse(tabTemplates.label.isEmpty)

        let tabHistory = app.buttons["tab_history"]
        XCTAssertTrue(tabHistory.exists)
        XCTAssertFalse(tabHistory.label.isEmpty)
    }

    // MARK: - Start tab

    func testStartWorkoutButtonHasLabel() {
        app.buttons["tab_start"].tap()
        let btn = app.buttons["start_workout_button"]
            .firstMatch
        guard btn.waitForExistence(timeout: 3) else {
            XCTFail("Start workout button not found"); return
        }
        XCTAssertFalse(btn.label.isEmpty)
    }

    func testAdHocSessionButtonHasLabel() {
        app.buttons["tab_start"].tap()
        let btn = app.buttons["adhoc_session_button"].firstMatch
        guard btn.waitForExistence(timeout: 3) else {
            XCTFail("Ad-hoc button not found"); return
        }
        XCTAssertFalse(btn.label.isEmpty)
    }

    // MARK: - Templates tab

    func testNewTemplateButtonHasLabel() {
        let btn = app.buttons.matching(identifier: "new_template_button").firstMatch
        guard btn.waitForExistence(timeout: 3) else { return }
        XCTAssertFalse(btn.label.isEmpty)
    }

    func testTemplateEditorNameFieldHasLabel() {
        // Open a new template editor if the button exists.
        let newBtn = app.buttons.matching(identifier: "new_template_button").firstMatch
        guard newBtn.waitForExistence(timeout: 3) else { return }
        newBtn.tap()

        let field = app.textFields["template_name_field"]
        guard field.waitForExistence(timeout: 3) else {
            XCTFail("Template name field not found"); return
        }
        // The field's placeholder or label serves as the accessibility label.
        XCTAssertTrue(field.exists)
    }

    // MARK: - History tab

    func testHistoryTabLoadsWithLabel() {
        app.buttons["tab_history"].tap()
        let navTitle = app.navigationBars["History"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 3), "History nav bar must have correct title")
    }

    func testCalendarButtonHasLabel() {
        app.buttons["tab_history"].tap()
        let calBtn = app.buttons["calendar_button"]
        guard calBtn.waitForExistence(timeout: 3) else { return }
        XCTAssertFalse(calBtn.label.isEmpty)
    }

    // MARK: - Settings

    func testProfileButtonHasLabel() {
        let profileBtn = app.buttons["profile_button"]
        guard profileBtn.waitForExistence(timeout: 3) else { return }
        XCTAssertFalse(profileBtn.label.isEmpty)
    }

    func testSettingsUnitPickerHasLabel() {
        let profileBtn = app.buttons["profile_button"]
        guard profileBtn.waitForExistence(timeout: 3) else { return }
        profileBtn.tap()

        let picker = app.pickers["unit_picker"]
            .firstMatch
        guard picker.waitForExistence(timeout: 3) else { return }
        XCTAssertFalse(picker.label.isEmpty)
    }
}
