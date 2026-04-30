import XCTest

/// Shared UI-test helper utilities for navigating the app and interacting with common UI elements.
final class Helpers {

  /// Opens the Overview tab and waits for the "Mole Overview" headline to appear.
  static func openOverviewTab(
    in app: XCUIApplication,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    app.tabBars.buttons["Overview"].tap()
    XCTAssertTrue(
      app.staticTexts["Mole Overview"].waitForExistence(timeout: 3), file: file, line: line)
  }

  /// Opens the Overview tab when a detail or evolution page is already open, accepting either the overview headline or the detail page picker as success.
  static func openOverviewTabWhenDetailOrEvolutionIsOpen(
    in app: XCUIApplication,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    app.tabBars.buttons["Overview"].tap()
    XCTAssertTrue(
      app.staticTexts["Mole Overview"].waitForExistence(timeout: 3)
        || app.segmentedControls["moleDetailPagePicker"].waitForExistence(timeout: 3),
      "Either overview headline or detail page picker should be visible after tapping overview tab",
      file: file,
      line: line
    )
  }

  /// Opens the Reminder tab and waits for the "Default Reminder Enabled" label to appear.
  static func openReminderTab(
    in app: XCUIApplication,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    app.tabBars.buttons["Reminder"].tap()
    XCTAssertTrue(
      app.staticTexts["Default Reminder Enabled"].waitForExistence(timeout: 3),
      "Default reminder text should be visible", file: file, line: line)

  }
  /// Opens the Capture tab and waits for either the placeholder headline or the segmentation view to appear.
  static func openCaptureTab(
    in app: XCUIApplication,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    let captureTab = app.tabBars.buttons["Capture"]
    XCTAssertTrue(
      captureTab.waitForExistence(timeout: 3),
      "Capture tab button should exist in the tab bar",
      file: file,
      line: line
    )
    captureTab.tap()

    XCTAssertTrue(
      captureTab.isSelected,
      "Capture tab should be selected after opening it",
      file: file,
      line: line
    )

    let placeholderHeadline = app.staticTexts["Opening camera..."].firstMatch
    let segmentationRoot = app.otherElements["moleSegmentationView"].firstMatch
    let settingsButton = app.buttons["segmentationSettingsButton"].firstMatch

    XCTAssertTrue(
      placeholderHeadline.waitForExistence(timeout: 3)
        || segmentationRoot.waitForExistence(timeout: 3)
        || settingsButton.waitForExistence(timeout: 3),
      "Capture tab should show either the placeholder headline or the segmentation screen",
      file: file,
      line: line
    )
  }

  /// Navigates to the mole detail page for the given person and mole name.
  static func openMoleDetail(
    person personName: String,
    mole moleName: String,
    in app: XCUIApplication,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    openOverviewTab(in: app, file: file, line: line)
    movePersonSelection(to: personName, in: app)

    let moleLabel = app.staticTexts[moleName].firstMatch
    XCTAssertTrue(
      moleLabel.waitForExistence(timeout: 3), "Could not find mole row: \(moleName)", file: file,
      line: line)
    moleLabel.tap()

    XCTAssertTrue(
      app.segmentedControls["moleDetailPagePicker"].waitForExistence(timeout: 3),
      "Mole detail page picker should be visible after opening detail",
      file: file,
      line: line
    )
  }

  /// Switches the mole detail page picker to the Evolution segment.
  static func switchToEvolution(in app: XCUIApplication) {
    let pagePicker = app.segmentedControls["moleDetailPagePicker"]
    XCTAssertTrue(pagePicker.waitForExistence(timeout: 3))
    pagePicker.buttons["Evolution"].tap()
  }

  /// Switches the mole detail page picker to the Detail segment.
  static func switchToDetail(in app: XCUIApplication) {
    let pagePicker = app.segmentedControls["moleDetailPagePicker"]
    XCTAssertTrue(pagePicker.waitForExistence(timeout: 3))
    pagePicker.buttons["Detail"].tap()
  }

  /// Taps the mole picker in the detail title bar and selects the specified mole.
  static func chooseMoleFromDetailTitle(_ moleName: String, in app: XCUIApplication) {
    let titleMenu = app.buttons["moleDetailMolePicker"]
    XCTAssertTrue(titleMenu.waitForExistence(timeout: 3))
    titleMenu.tap()
    app.buttons[moleName].tap()
  }

  /// Selects the person with the given name in the overview person navigator.
  static func selectPerson(_ name: String, in app: XCUIApplication) {
    movePersonSelection(to: name, in: app)
  }

  /// Navigates forward or backward through the person list until the specified person is visible.
  static func movePersonSelection(to name: String, in app: XCUIApplication) {
    if app.staticTexts[name].exists { return }

    let maxMoves = 6
    let rightButton = app.buttons["chevron.right"]
    let leftButton = app.buttons["chevron.left"]

    var moves = 0
    while !app.staticTexts[name].exists && rightButton.isEnabled && moves < maxMoves {
      rightButton.tap()
      moves += 1
    }

    if app.staticTexts[name].exists { return }

    moves = 0
    while !app.staticTexts[name].exists && leftButton.isEnabled && moves < maxMoves {
      leftButton.tap()
      moves += 1
    }

    XCTAssertTrue(
      app.staticTexts[name].waitForExistence(timeout: 1), "Expected selected person to be \(name)")
  }

  /// Long-presses a person cell to reveal the context menu and confirms the delete action.
  static func deletePerson(_ name: String, in app: XCUIApplication) {
    let personCell = app.staticTexts[name]
    XCTAssertTrue(
      personCell.waitForExistence(timeout: 3), "Person \(name) should exist before deletion")

    personCell.press(forDuration: 1.0)
    app.buttons["Delete"].tap()
    app.alerts.buttons["Delete"].tap()
  }

  /// Long-presses a person cell and renames the person from `oldName` to `newName` via the Edit Name alert.
  static func switchNameOfPerson(from oldName: String, to newName: String, in app: XCUIApplication)
  {
    let personCell = app.staticTexts[oldName]
    XCTAssertTrue(
      personCell.waitForExistence(timeout: 3), "Person \(oldName) should exist before renaming")

    personCell.press(forDuration: 1.0)
    let editButton = app.buttons["Edit Name"]
    XCTAssertTrue(editButton.waitForExistence(timeout: 3), "Edit Name action should appear")
    editButton.tap()

    let editAlert = app.alerts["Edit Person"]
    XCTAssertTrue(editAlert.waitForExistence(timeout: 3), "Edit Person alert should appear")

    let textField = editAlert.textFields["Name"]
    XCTAssertTrue(textField.waitForExistence(timeout: 3), "Edit name text field should appear")
    textField.tap()
    if let current = textField.value as? String, !current.isEmpty {
      textField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
    }
    textField.typeText(newName)

    editAlert.buttons["Save"].tap()
  }

  /// Swipes left on a mole row to reveal the delete swipe action button.
  static func revealDeleteMoleSwipeAction(for moleName: String, in app: XCUIApplication) {
    let moleRowLabel = app.staticTexts[moleName].firstMatch
    XCTAssertTrue(
      moleRowLabel.waitForExistence(timeout: 3), "Mole row should exist before swipe: \(moleName)")

    let deleteButton = app.buttons["overviewDeleteMoleButton_\(moleName)"]
    if !deleteButton.exists {
      moleRowLabel.swipeLeft()
    }
    if !deleteButton.exists {
      moleRowLabel.swipeLeft()
    }

    XCTAssertTrue(
      deleteButton.waitForExistence(timeout: 2),
      "Swipe action should reveal delete button for mole: \(moleName)"
    )
  }
}
