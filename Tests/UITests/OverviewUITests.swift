import XCTest

final class OverviewUITests: XCTestCase {

    private var app: XCUIApplication!
    private let defaultLaunchArguments = ["-UITest_InMemoryStore", "-SkipModelLoading"]

    override func setUpWithError() throws {
        continueAfterFailure = false
        launchApp(arguments: defaultLaunchArguments)
    }

    // MARK: - Person Management
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

    func testCreatePersonCancelDoesNotAddPerson() {
        Helpers.openOverviewTab(in: app)

        app.buttons["person.fill.badge.plus"].firstMatch.tap()

        let addAlert = app.alerts["Add Person"]
        XCTAssertTrue(addAlert.waitForExistence(timeout: 3))

        let nameField = addAlert.textFields["Name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.replaceText(with: "Casey")

        addAlert.buttons["Cancel"].tap()

        XCTAssertFalse(app.staticTexts["Casey"].exists, "Canceled add should not create a person")
        XCTAssertTrue(app.staticTexts["Alex"].exists, "Selection should remain unchanged after canceling add")
    }

    func testCreatePersonWithEmptyNameDismissesAlertAndDoesNotCreatePerson() {
        Helpers.openOverviewTab(in: app)

        app.buttons["person.fill.badge.plus"].firstMatch.tap()

        let addAlert = app.alerts["Add Person"]
        XCTAssertTrue(addAlert.waitForExistence(timeout: 3))

        addAlert.buttons["Add"].tap()

        XCTAssertFalse(addAlert.waitForExistence(timeout: 1), "Add alert should dismiss after attempting to add an empty name")
        XCTAssertTrue(app.staticTexts["Alex"].waitForExistence(timeout: 3), "Selection should remain on Alex when empty name is submitted")
    }

    func testRenamePersonCancelDoesNotChangeName() {
        Helpers.openOverviewTab(in: app)

        let currentPerson = app.staticTexts["Alex"]
        XCTAssertTrue(currentPerson.waitForExistence(timeout: 3))
        currentPerson.press(forDuration: 1.0)

        let editButton = app.buttons["Edit Name"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 3))
        editButton.tap()

        let editAlert = app.alerts["Edit Person"]
        XCTAssertTrue(editAlert.waitForExistence(timeout: 3))

        let nameField = editAlert.textFields["Name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.replaceText(with: "Alex Temp")

        editAlert.buttons["Cancel"].tap()

        XCTAssertTrue(app.staticTexts["Alex"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["Alex Temp"].exists, "Canceled rename should not update person name")
    }

    func testRenamePersonWithEmptyNameDoesNotChangeName() {
        Helpers.openOverviewTab(in: app)

        let currentPerson = app.staticTexts["Alex"]
        XCTAssertTrue(currentPerson.waitForExistence(timeout: 3))
        currentPerson.press(forDuration: 1.0)

        let editButton = app.buttons["Edit Name"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 3))
        editButton.tap()

        let editAlert = app.alerts["Edit Person"]
        XCTAssertTrue(editAlert.waitForExistence(timeout: 3))

        let nameField = editAlert.textFields["Name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.replaceText(with: "")

        editAlert.buttons["Save"].tap()

        XCTAssertTrue(app.staticTexts["Alex"].waitForExistence(timeout: 3), "Saving empty name should keep previous name")
    }

    func testDeletePersonCancelKeepsPerson() {
        Helpers.openOverviewTab(in: app)
        Helpers.movePersonSelection(to: "Taylor", in: app)

        let taylor = app.staticTexts["Taylor"]
        XCTAssertTrue(taylor.waitForExistence(timeout: 3))
        taylor.press(forDuration: 1.0)

        let deleteAction = app.buttons["Delete"]
        XCTAssertTrue(deleteAction.waitForExistence(timeout: 3))
        deleteAction.tap()

        let deleteAlert = app.alerts["Delete Person"]
        XCTAssertTrue(deleteAlert.waitForExistence(timeout: 3))
        deleteAlert.buttons["Cancel"].tap()

        XCTAssertTrue(app.staticTexts["Taylor"].waitForExistence(timeout: 3), "Canceling delete should keep person")
    }

    func testDeletePersonConfirmRemovesPersonAndFallsBackSelection() {
        Helpers.openOverviewTab(in: app)
        Helpers.movePersonSelection(to: "Taylor", in: app)

        let taylor = app.staticTexts["Taylor"]
        XCTAssertTrue(taylor.waitForExistence(timeout: 3))
        taylor.press(forDuration: 1.0)

        let deleteAction = app.buttons["Delete"]
        XCTAssertTrue(deleteAction.waitForExistence(timeout: 3))
        deleteAction.tap()

        let deleteAlert = app.alerts["Delete Person"]
        XCTAssertTrue(deleteAlert.waitForExistence(timeout: 3))
        deleteAlert.buttons["Delete"].tap()

        XCTAssertTrue(app.staticTexts["Alex"].waitForExistence(timeout: 3), "Selection should fall back after deleting selected person")
    }
    // MARK: - Mole Management
    
    func testCancelDeleteMoleFromOverviewKeepsMole() {
        Helpers.openOverviewTab(in: app)

        let moleName = "Back Mole"
        Helpers.revealDeleteMoleSwipeAction(for: moleName, in: app)

        let deleteButton = app.buttons["overviewDeleteMoleButton_\(moleName)"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 2))
        deleteButton.tap()

        let deleteAlert = app.alerts["Delete Mole"]
        XCTAssertTrue(deleteAlert.waitForExistence(timeout: 3))
        deleteAlert.buttons["Cancel"].tap()

        XCTAssertTrue(
            app.staticTexts[moleName].waitForExistence(timeout: 3),
            "Canceling delete should keep the mole in overview"
        )
    }

    func testConfirmDeleteMoleFromOverviewRemovesMole() {
        Helpers.openOverviewTab(in: app)

        let moleName = "Back Mole"
        Helpers.revealDeleteMoleSwipeAction(for: moleName, in: app)

        let deleteButton = app.buttons["overviewDeleteMoleButton_\(moleName)"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 2))
        deleteButton.tap()

        let deleteAlert = app.alerts["Delete Mole"]
        XCTAssertTrue(deleteAlert.waitForExistence(timeout: 3))
        deleteAlert.buttons["Delete"].tap()

        XCTAssertFalse(
            app.staticTexts[moleName].waitForExistence(timeout: 2),
            "Confirmed delete should remove the mole from overview"
        )
        XCTAssertTrue(app.staticTexts["Left Arm Mole"].exists)
    }

    func testChangingPersonInReminderDismissesOpenDetailOrEvolutionPage() {
        Helpers.openMoleDetail(person: "Alex", mole: "Left Arm Mole", in: app)
        Helpers.switchToEvolution(in: app)

        let detailPicker = app.segmentedControls["moleDetailPagePicker"]
        XCTAssertTrue(detailPicker.waitForExistence(timeout: 3), "Detail/Evolution picker should be visible before changing person")

        Helpers.openReminderTab(in: app)
        Helpers.movePersonSelection(to: "Taylor", in: app)
        XCTAssertTrue(app.staticTexts["Taylor"].waitForExistence(timeout: 3), "Reminder selection should switch to Taylor")

        Helpers.openOverviewTab(in: app)

        XCTAssertFalse(
            detailPicker.waitForExistence(timeout: 2),
            "Detail/Evolution page should be dismissed when person is changed from Reminder"
        )
        XCTAssertTrue(app.staticTexts["Taylor"].waitForExistence(timeout: 3), "Overview should reflect the newly selected person")
    }
   
        
        
    // MARK: - Persistent Storage
    func testRenamedPersonPersistsAfterRelaunch() {
        app.terminate()
        launchApp(arguments: ["-UITest_PersistentStore", "-UITest_ResetStore", "-SkipModelLoading"])
        Helpers.openOverviewTab(in: app)

        let currentPerson = app.staticTexts["Alex"]
        XCTAssertTrue(currentPerson.waitForExistence(timeout: 3))
        currentPerson.press(forDuration: 1.0)

        let editButton = app.buttons["Edit Name"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 3))
        editButton.tap()

        let editAlert = app.alerts["Edit Person"]
        XCTAssertTrue(editAlert.waitForExistence(timeout: 3))

        let nameField = editAlert.textFields["Name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.replaceText(with: "Alex Persisted")
        editAlert.buttons["Save"].tap()

        XCTAssertTrue(app.staticTexts["Alex Persisted"].waitForExistence(timeout: 3))

        app.terminate()
        launchApp(arguments: ["-UITest_PersistentStore", "-SkipModelLoading"])
        Helpers.openOverviewTab(in: app)

        XCTAssertTrue(
            app.staticTexts["Alex Persisted"].waitForExistence(timeout: 3),
            "Renamed person should persist after relaunch when using persistent UI-test store"
        )
    }

    func testCreatedPersonPersistsAfterRelaunch() {
        app.terminate()
        launchApp(arguments: ["-UITest_PersistentStore", "-UITest_ResetStore", "-SkipModelLoading"])
        Helpers.openOverviewTab(in: app)

        let addPersonButton = app.buttons["person.fill.badge.plus"].firstMatch
        XCTAssertTrue(addPersonButton.waitForExistence(timeout: 3))
        addPersonButton.tap()

        let addAlert = app.alerts["Add Person"]
        XCTAssertTrue(addAlert.waitForExistence(timeout: 3))

        let nameField = addAlert.textFields["Name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.replaceText(with: "Morgan")
        addAlert.buttons["Add"].tap()

        XCTAssertTrue(app.staticTexts["Morgan"].waitForExistence(timeout: 3))

        app.terminate()
        launchApp(arguments: ["-UITest_PersistentStore", "-SkipModelLoading"])
        Helpers.openOverviewTab(in: app)
        Helpers.movePersonSelection(to: "Morgan", in: app)
        XCTAssertTrue(
            app.staticTexts["Morgan"].waitForExistence(timeout: 3),
            "Created person should persist after relaunch when using persistent UI-test store"
        )
    }

    func testDeletedPersonPersistsAfterRelaunch() {
        app.terminate()
        launchApp(arguments: ["-UITest_PersistentStore", "-UITest_ResetStore", "-SkipModelLoading"])
        Helpers.openOverviewTab(in: app)

        Helpers.movePersonSelection(to: "Taylor", in: app)
        let taylor = app.staticTexts["Taylor"]
        XCTAssertTrue(taylor.waitForExistence(timeout: 3))
        taylor.press(forDuration: 1.0)

        let deleteAction = app.buttons["Delete"]
        XCTAssertTrue(deleteAction.waitForExistence(timeout: 3))
        deleteAction.tap()

        let deleteAlert = app.alerts["Delete Person"]
        XCTAssertTrue(deleteAlert.waitForExistence(timeout: 3))
        deleteAlert.buttons["Delete"].tap()

        XCTAssertFalse(app.staticTexts["Taylor"].exists, "Deleted person should no longer exist")

        app.terminate()
        launchApp(arguments: ["-UITest_PersistentStore", "-SkipModelLoading"])
        Helpers.openOverviewTab(in: app)

        Helpers.movePersonSelection(to: "Jordan", in: app)
        XCTAssertTrue(app.staticTexts["Jordan"].waitForExistence(timeout: 3))

        let rightButton = app.buttons["chevron.right"]
        XCTAssertFalse(rightButton.isEnabled, "Right navigation should be disabled at last available person")

        XCTAssertFalse(
            app.staticTexts["Taylor"].exists,
            "Taylor should not be reachable in overview after being deleted and app relaunch"
        )
    }

    func testDeletedMolePersistsAfterRelaunch() {
        app.terminate()
        launchApp(arguments: ["-UITest_PersistentStore", "-UITest_ResetStore", "-SkipModelLoading"])
        Helpers.openOverviewTab(in: app)

        let moleName = "Back Mole"
        Helpers.revealDeleteMoleSwipeAction(for: moleName, in: app)

        let deleteButton = app.buttons["overviewDeleteMoleButton_\(moleName)"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 2))
        deleteButton.tap()

        let deleteAlert = app.alerts["Delete Mole"]
        XCTAssertTrue(deleteAlert.waitForExistence(timeout: 3))
        deleteAlert.buttons["Delete"].tap()

        XCTAssertFalse(app.staticTexts[moleName].exists, "Deleted mole should no longer exist")

        app.terminate()
        launchApp(arguments: ["-UITest_PersistentStore", "-SkipModelLoading"])
        Helpers.openOverviewTab(in: app)

        XCTAssertFalse(
            app.staticTexts[moleName].exists,
            "Deleted mole should not be reachable in overview after being deleted and app relaunch"
        )
    }

    private func launchApp(arguments: [String]) {
        app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
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
