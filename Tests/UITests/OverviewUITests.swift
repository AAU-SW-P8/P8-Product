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

    // MARK: - Overview Filter & Sort

    func testOverviewFilterPopupReopensWithBodyPartDropdownCollapsed() {
        Helpers.openOverviewTab(in: app)

        openOverviewFilterPopup()
        tapElement(withIdentifier: "overviewBodyPartDropdownButton")

        let dropdownList = uiElement(withIdentifier: "overviewBodyPartDropdownList")
        XCTAssertTrue(dropdownList.waitForExistence(timeout: 3), "Body-part dropdown should expand after tapping")

        tapElement(withIdentifier: "overviewFilterDoneButton")
        XCTAssertFalse(dropdownList.waitForExistence(timeout: 1), "Dropdown should no longer be visible when popup closes")

        openOverviewFilterPopup()
        XCTAssertFalse(dropdownList.exists, "Body-part dropdown should be collapsed when reopening popup")
    }

    func testOverviewBodyPartMultiSelectFiltering() {
        Helpers.openOverviewTab(in: app)

        openOverviewFilterPopup()
        openBodyPartDropdownInFilterPopup()

        let backOption = bodyPartOptionButton("Back")
        let leftArmOption = bodyPartOptionButton("Left Arm")
        XCTAssertTrue(backOption.waitForExistence(timeout: 3))
        XCTAssertTrue(leftArmOption.waitForExistence(timeout: 3))

        tapElement(withIdentifier: "overviewBodyPartOption_Back")
        XCTAssertTrue(uiElement(withIdentifier: "overviewBodyPartDropdownList").exists, "Dropdown should stay open after one selection")

        tapElement(withIdentifier: "overviewBodyPartOption_Left_Arm")
        XCTAssertTrue(uiElement(withIdentifier: "overviewBodyPartDropdownList").exists, "Dropdown should stay open for multi-select")

        tapElement(withIdentifier: "overviewFilterDoneButton")

        XCTAssertTrue(uiElement(withIdentifier: "overviewMoleRow_Back Mole").waitForExistence(timeout: 3))
        XCTAssertTrue(uiElement(withIdentifier: "overviewMoleRow_Left Arm Mole").waitForExistence(timeout: 3))

        openOverviewFilterPopup()
        openBodyPartDropdownInFilterPopup()
        tapElement(withIdentifier: "overviewBodyPartClearButton")
        tapElement(withIdentifier: "overviewBodyPartOption_Back")
        tapElement(withIdentifier: "overviewFilterDoneButton")

        XCTAssertTrue(uiElement(withIdentifier: "overviewMoleRow_Back Mole").waitForExistence(timeout: 3))
        XCTAssertFalse(
            uiElement(withIdentifier: "overviewMoleRow_Left Arm Mole").waitForExistence(timeout: 1),
            "Only Back Mole should remain when filtering by Back body part"
        )
    }

    func testOverviewSortPickerSupportsAlphabeticalAndRecent() {
        Helpers.openOverviewTab(in: app)

        openOverviewFilterPopup()
        tapElement(withIdentifier: "overviewFilterResetButton")

        let sortPicker = uiElement(withIdentifier: "overviewSortPicker")
        XCTAssertTrue(sortPicker.waitForExistence(timeout: 3))

        if sortPicker.isHittable {
            sortPicker.tap()
        } else {
            sortPicker.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        app.buttons["A-Z"].firstMatch.tap()
        tapElement(withIdentifier: "overviewFilterDoneButton")

        let backLabel = app.staticTexts["Back Mole"].firstMatch
        let leftArmLabel = app.staticTexts["Left Arm Mole"].firstMatch
        XCTAssertTrue(backLabel.waitForExistence(timeout: 3))
        XCTAssertTrue(leftArmLabel.waitForExistence(timeout: 3))
        XCTAssertLessThan(backLabel.frame.minY, leftArmLabel.frame.minY, "A-Z sort should place Back Mole before Left Arm Mole")

        openOverviewFilterPopup()
        let sortPickerAgain = uiElement(withIdentifier: "overviewSortPicker")
        XCTAssertTrue(sortPickerAgain.waitForExistence(timeout: 3))

        if sortPickerAgain.isHittable {
            sortPickerAgain.tap()
        } else {
            sortPickerAgain.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        app.buttons["Recent"].firstMatch.tap()
        tapElement(withIdentifier: "overviewFilterDoneButton")

        XCTAssertLessThan(leftArmLabel.frame.minY, backLabel.frame.minY, "Recent sort should place Left Arm Mole before Back Mole")
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

    private func openOverviewFilterPopup() {
        let visiblePopupTitle = app.staticTexts["Filter & Sort"].firstMatch
        if visiblePopupTitle.waitForExistence(timeout: 1) {
            return
        }

        tapElement(identifier: "overviewFilterButton", fallbackButtonTitle: "Open Filters")

        let marker = uiElement(withIdentifier: "overviewFilterPopupVisibleMarker")
        let doneButton = uiElement(withIdentifier: "overviewFilterDoneButton")
        let title = uiElement(withIdentifier: "overviewFilterPopupTitle")

        let popupVisible = visiblePopupTitle.waitForExistence(timeout: 3)
            || marker.waitForExistence(timeout: 3)
            || doneButton.waitForExistence(timeout: 3)
            || title.waitForExistence(timeout: 3)

        XCTAssertTrue(popupVisible, "Filter popup should be visible after tapping filter button")
    }

    private func openBodyPartDropdownInFilterPopup() {
        tapElement(identifier: "overviewBodyPartDropdownButton", fallbackButtonTitle: "Body Part Filter")

        let dropdownList = uiElement(withIdentifier: "overviewBodyPartDropdownList")
        XCTAssertTrue(dropdownList.waitForExistence(timeout: 3), "Body-part dropdown list should be visible")
    }

    private func bodyPartOptionButton(_ bodyPart: String) -> XCUIElement {
        let normalized = bodyPart.replacingOccurrences(of: " ", with: "_")
        return uiElement(withIdentifier: "overviewBodyPartOption_\(normalized)")
    }

    private func uiElement(withIdentifier identifier: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: identifier)
            .firstMatch
    }

    private func tapElement(withIdentifier identifier: String, timeout: TimeInterval = 3) {
        tapElement(identifier: identifier, fallbackButtonTitle: nil, timeout: timeout)
    }

    private func tapElement(identifier: String, fallbackButtonTitle: String? = nil, timeout: TimeInterval = 3) {
        let element = uiElement(withIdentifier: identifier)
        if element.waitForExistence(timeout: timeout) {
            if element.isHittable {
                element.tap()
            } else {
                element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
            return
        }

        if let fallbackButtonTitle {
            let fallbackButton = app.buttons[fallbackButtonTitle].firstMatch
            XCTAssertTrue(
                fallbackButton.waitForExistence(timeout: timeout),
                "Expected fallback button '\(fallbackButtonTitle)' for identifier '\(identifier)'"
            )
            if fallbackButton.isHittable {
                fallbackButton.tap()
            } else {
                fallbackButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
            return
        }

        XCTFail("Expected element '\(identifier)' to exist")
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
