import XCTest

final class TemplateUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--skip-onboarding"]
        app.launch()
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
    func testRemovingSetWhileCreatingTemplateKeepsExercise() {
        openTemplateEditorWithExercise(name: "Crash Regression", exerciseIdentifier: "exercise_Push_Up")

        let addSetButton = app.buttons["template_add_set_button"]
        scrollUntilVisible(addSetButton)
        XCTAssertTrue(addSetButton.waitForExistence(timeout: 2))
        addSetButton.tap()

        let removeSetButton = app.buttons["template_remove_set_button"].firstMatch
        XCTAssertTrue(removeSetButton.waitForExistence(timeout: 2))
        removeSetButton.tap()

        XCTAssertTrue(app.otherElements["selected_exercise_Push_Up"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["1 sets"].exists)
        XCTAssertTrue(app.buttons["add_exercise_button"].exists)
    }

    func testTemplateEditorPreventsDuplicateExercises() {
        openTemplateEditorWithExercise(name: "Duplicate Regression", exerciseIdentifier: "exercise_Push_Up")
        app.buttons["Done"].tap()

        let addExerciseButton = app.buttons["add_exercise_button"]
        XCTAssertTrue(addExerciseButton.waitForExistence(timeout: 2))
        addExerciseButton.tap()

        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 4))
        searchField.tap()
        searchField.typeText("Push Up")

        let exercise = app.buttons["exercise_Push_Up"].firstMatch
        XCTAssertTrue(exercise.waitForExistence(timeout: 4))
        exercise.tap()

        XCTAssertTrue(app.searchFields.firstMatch.exists)
    }

    private func openTemplateEditorWithExercise(name: String, exerciseIdentifier: String) {
        app.buttons["new_template_button"].tap()

        let nameField = app.textFields["template_name_field"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        nameField.tap()
        nameField.typeText(name)
        app.buttons["Next"].tap()

        let addExerciseButton = app.buttons["add_exercise_button"]
        XCTAssertTrue(addExerciseButton.waitForExistence(timeout: 2))
        addExerciseButton.tap()

        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 4))
        searchField.tap()
        searchField.typeText("Push Up")

        let exercise = app.buttons[exerciseIdentifier].firstMatch
        XCTAssertTrue(exercise.waitForExistence(timeout: 4))
        exercise.tap()

        XCTAssertTrue(app.navigationBars[name].waitForExistence(timeout: 4))
    }

    private func scrollUntilVisible(_ element: XCUIElement, attempts: Int = 5) {
        var remainingAttempts = attempts
        while element.exists == false && remainingAttempts > 0 {
            app.swipeUp()
            remainingAttempts -= 1
        }
    }
}
