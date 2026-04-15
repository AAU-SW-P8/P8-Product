import XCTest

final class OverviewUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchArguments.append("-UITest_InMemoryStore")
        app.launchArguments.append("-SkipModelLoading")
        app.launch()
    }

    func testUserCanRenamePerson() {
        Helpers.openOverviewTab(in: app)

        let currentPerson = app.staticTexts["Alex"]
        XCTAssertTrue(currentPerson.waitForExistence(timeout: 3), "Expected Alex to be selected at launch")

        currentPerson.press(forDuration: 1.0)
        let editButton = app.buttons["Edit Name"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 3), "Edit Name action should appear")
        editButton.tap()

        let editAlert = app.alerts["Edit Person"]
        XCTAssertTrue(editAlert.waitForExistence(timeout: 3), "Edit Person alert should be shown")

        let nameField = editAlert.textFields["Name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3), "Name field should be visible in edit alert")
        nameField.replaceText(with: "Alex Renamed")

        editAlert.buttons["Save"].tap()

        XCTAssertTrue(app.staticTexts["Alex Renamed"].waitForExistence(timeout: 3), "Person name should update after saving")
    }

    func testUserCanCreateNewPerson() {
        Helpers.openOverviewTab(in: app)

        let addPersonButton = app.buttons["person.fill.badge.plus"].firstMatch
        XCTAssertTrue(addPersonButton.waitForExistence(timeout: 3), "Add person button should be visible")
        addPersonButton.tap()

        let addAlert = app.alerts["Add Person"]
        XCTAssertTrue(addAlert.waitForExistence(timeout: 3), "Add Person alert should be shown")

        let nameField = addAlert.textFields["Name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3), "Name field should be visible in add alert")
        nameField.replaceText(with: "Morgan")

        addAlert.buttons["Add"].tap()

        XCTAssertTrue(app.staticTexts["Morgan"].waitForExistence(timeout: 3), "Newly created person should be selected")
    }
}

private extension XCUIElement {
    func replaceText(with text: String) {
        tap()

        if let currentValue = value as? String, currentValue.isEmpty == false {
            typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count))
        }

        typeText(text)
    }
}
