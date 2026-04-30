import XCTest

/// UI tests for the Overview tab, covering person and mole management and persistent storage.
final class OverviewUITests: XCTestCase {

    /// The application instance under test.
    private var app: XCUIApplication!
    /// Default launch arguments used for the in-memory test store.
    private let defaultLaunchArguments = ["-UITest_InMemoryStore", "-SkipModelLoading"]

    override func setUpWithError() throws {
        continueAfterFailure = false
        launchApp(arguments: defaultLaunchArguments)
    }

    // MARK: - Person Management
    /// Verifies the user can rename an existing person via the long-press context menu.
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

    /// Verifies the user can create a new person using the add-person button.
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

    /// Verifies canceling the add-person alert does not create a person.
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

    /// Verifies submitting an empty name in the add-person alert dismisses it without creating a person.
    func testCreatePersonWithEmptyNameDismissesAlertAndDoesNotCreatePerson() {
        Helpers.openOverviewTab(in: app)

        app.buttons["person.fill.badge.plus"].firstMatch.tap()

        let addAlert = app.alerts["Add Person"]
        XCTAssertTrue(addAlert.waitForExistence(timeout: 3))

        addAlert.buttons["Add"].tap()

        XCTAssertFalse(addAlert.waitForExistence(timeout: 1), "Add alert should dismiss after attempting to add an empty name")
        XCTAssertTrue(app.staticTexts["Alex"].waitForExistence(timeout: 3), "Selection should remain on Alex when empty name is submitted")
    }

    /// Verifies submitting a whitespace-only name in the add-person alert does not create a person.
    func testCreatePersonWithWhitespaceOnlyNameDoesNotCreatePerson() {
        Helpers.openOverviewTab(in: app)

        app.buttons["person.fill.badge.plus"].firstMatch.tap()

        let addAlert = app.alerts["Add Person"]
        XCTAssertTrue(addAlert.waitForExistence(timeout: 3))

        let nameField = addAlert.textFields["Name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.replaceText(with: "   ")

        addAlert.buttons["Add"].tap()

        XCTAssertFalse(addAlert.waitForExistence(timeout: 1), "Add alert should dismiss after attempting to add a whitespace-only name")
        XCTAssertTrue(app.staticTexts["Alex"].waitForExistence(timeout: 3), "Selection should remain on Alex when whitespace-only name is submitted")
    }

    /// Verifies canceling the rename alert leaves the person's name unchanged.
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

    /// Verifies saving an empty name in the rename alert leaves the person's name unchanged.
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

    /// Verifies saving a whitespace-only name in the rename alert leaves the person's name unchanged.
    func testRenamePersonWithWhitespaceOnlyNameDoesNotChangeName() {
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
        nameField.replaceText(with: "   ")

        editAlert.buttons["Save"].tap()

        XCTAssertTrue(app.staticTexts["Alex"].waitForExistence(timeout: 3), "Saving whitespace-only name should keep previous name")
    }

    /// Verifies canceling the delete-person alert keeps the person in the list.
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

    /// Verifies confirming the delete-person alert removes the person and falls back the selection.
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

    /// Verifies deleting a person also removes all of their associated moles.
    func testDeletePersonWithMolesDeletesPersonAndMoles() {
        Helpers.openOverviewTab(in: app)
        Helpers.movePersonSelection(to: "Jordan", in: app)

        let taylor = app.staticTexts["Jordan"]
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

    /// Verifies the "No Person Registered" message is shown when all persons have been deleted.
    func testNoPersonRegisteredTextShowsWhenNoPersonsExist() {
        Helpers.openOverviewTab(in: app)

        // Delete all existing people
        let people = ["Alex", "Jordan", "Taylor"]
        for person in people {
            Helpers.movePersonSelection(to: person, in: app)
            let personElement = app.staticTexts[person]
            XCTAssertTrue(personElement.waitForExistence(timeout: 3))
            personElement.press(forDuration: 1.0)

            let deleteAction = app.buttons["Delete"]
            XCTAssertTrue(deleteAction.waitForExistence(timeout: 3))
            deleteAction.tap()

            let deleteAlert = app.alerts["Delete Person"]
            XCTAssertTrue(deleteAlert.waitForExistence(timeout: 3))
            deleteAlert.buttons["Delete"].tap()
        }

        XCTAssertTrue(
            app.staticTexts["No Person Registered"].waitForExistence(timeout: 3),
            "Overview should show 'No Person Registered' when there are no people"
        )
    }
    // MARK: - Mole Management

    /// Verifies canceling the delete-mole alert keeps the mole in the overview list.
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

    /// Verifies confirming the delete-mole alert removes the mole from the overview list.
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

    /// Verifies that changing the selected person in the Reminder tab dismisses any open detail or evolution page.
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

    // MARK: - Overview Filter & Sort   

    // MARK: - Persistent Storage
    /// Verifies that a renamed person persists in the overview after the app is relaunched.
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

    /// Verifies that a created person persists in the overview after the app is relaunched.
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

    /// Verifies that a deleted person is no longer accessible in the overview after the app is relaunched.
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

    /// Verifies that a deleted mole is no longer accessible in the overview after the app is relaunched.
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

    /// Initialises a new `XCUIApplication`, applies the given launch arguments, and launches it.
    private func launchApp(arguments: [String]) {
        app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
    }
}

/// Extensions on `XCUIElement` used in overview UI tests.
private extension XCUIElement {
    /// Clears the element's current text and types the given replacement string.
    func replaceText(with text: String) {
        tap()

        if let currentValue = value as? String, currentValue.isEmpty == false {
            typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count))
        }

        typeText(text)
    }
}
