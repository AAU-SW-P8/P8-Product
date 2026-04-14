//
//  ReminderViewUITests.swift
//  P8-ProductUITests
//
//  UI tests for the Reminder tab.
//

import XCTest

final class ReminderViewUITests: XCTestCase {

	private var app: XCUIApplication!
	private let reminderFrequencyButtonLabels = ["Default", "Weekly", "Monthly", "Quarterly"]

	override func setUpWithError() throws {
		continueAfterFailure = false
		app = XCUIApplication()
		app.launchArguments += ["-SkipModelLoading", "-UITest_InMemoryStore"]
		app.terminate()
		app.launch()

		app.tabBars.buttons["Reminder"].tap()
	}

	// MARK: - Helpers

	private var nextPersonButton: XCUIElement {
		app.buttons["chevron.right"]
	}

	private var previousPersonButton: XCUIElement {
		app.buttons["chevron.left"]
	}

	private func leftArmMoleCard() -> XCUIElement {
		app.otherElements.containing(.staticText, identifier: "Mole Left Arm Mole").firstMatch
	}

	private func firstMoleFrequencyButton() -> XCUIElement {
		let frequencyPredicate = NSPredicate(format: "label IN %@", reminderFrequencyButtonLabels)
		return leftArmMoleCard().buttons.matching(frequencyPredicate).firstMatch
	}

	private func defaultFrequencyButton() -> XCUIElement {
		let frequencyPredicate = NSPredicate(format: "label IN %@", reminderFrequencyButtonLabels)
		let frequencyButtons = app.buttons.matching(frequencyPredicate)

		var topMostButton = frequencyButtons.firstMatch
		var minY: CGFloat = .greatestFiniteMagnitude

		for index in 0..<frequencyButtons.count {
			let button = frequencyButtons.element(boundBy: index)
			guard button.exists else { continue }

			if button.frame.minY < minY {
				minY = button.frame.minY
				topMostButton = button
			}
		}

		return topMostButton
	}

	// MARK: - Smoke

	func testReminderTabShowsHeaderAndSections() {
		XCTAssertTrue(app.staticTexts["Reminder"].waitForExistence(timeout: 3))
		XCTAssertTrue(app.staticTexts["Default Reminder Enabled"].exists)
		XCTAssertTrue(app.staticTexts["Default Reminder Frequency"].exists)
		XCTAssertTrue(app.staticTexts["Upcoming Check-ins"].exists)
	}

	func testReminderTabShowsSeededPersonAndMoleCardContent() {
		XCTAssertTrue(app.staticTexts["Alex"].waitForExistence(timeout: 3))
		XCTAssertTrue(app.staticTexts["Mole Left Arm Mole"].waitForExistence(timeout: 3))
		XCTAssertTrue(app.staticTexts["Reminder"].exists)
		XCTAssertTrue(app.staticTexts["Reminder Frequency"].exists)
	}

	// MARK: - Person Switching

	func testNextPersonButtonSwitchesFromAlexToJordan() {
		XCTAssertTrue(app.staticTexts["Alex"].waitForExistence(timeout: 3))
		XCTAssertTrue(nextPersonButton.exists)

		nextPersonButton.tap()

		XCTAssertTrue(app.staticTexts["Jordan"].waitForExistence(timeout: 3))
	}

	func testPreviousPersonButtonDisabledOnFirstPerson() {
		XCTAssertTrue(app.staticTexts["Alex"].waitForExistence(timeout: 3))
		XCTAssertTrue(previousPersonButton.exists)
		XCTAssertFalse(previousPersonButton.isEnabled)
	}

	func testNextPersonButtonDisabledOnLastPerson() {
		// Verifies the forward navigation control is disabled on the final person.
		XCTAssertTrue(app.staticTexts["Alex"].waitForExistence(timeout: 3))

		nextPersonButton.tap()
		XCTAssertTrue(app.staticTexts["Jordan"].waitForExistence(timeout: 3))

		nextPersonButton.tap()
		XCTAssertTrue(app.staticTexts["Taylor"].waitForExistence(timeout: 3))
		XCTAssertFalse(nextPersonButton.isEnabled)
	}

	func testPreviousPersonButtonEnabledAfterMovingForward() {
		// Verifies the back navigation control re-enables after moving off the first person.
		XCTAssertTrue(app.staticTexts["Alex"].waitForExistence(timeout: 3))
		XCTAssertFalse(previousPersonButton.isEnabled)

		nextPersonButton.tap()

		XCTAssertTrue(app.staticTexts["Jordan"].waitForExistence(timeout: 3))
		XCTAssertTrue(previousPersonButton.isEnabled)
	}

	// MARK: - Reminder Controls

	func testReminderModeOptionsAreVisibleForMole() {
		XCTAssertTrue(app.staticTexts["Mole Left Arm Mole"].waitForExistence(timeout: 3))

		XCTAssertTrue(app.buttons["Follow Default"].waitForExistence(timeout: 3))
		XCTAssertTrue(app.buttons["Enabled"].exists)
		XCTAssertTrue(app.buttons["Disabled"].exists)
	}

	func testDefaultReminderToggleExists() {
		XCTAssertTrue(app.switches["Reminder Enabled"].waitForExistence(timeout: 3))
	}

	func testReminderModeChangesMoleFrequencyControlEnabledState() {
		// Verifies reminder mode toggles whether the per-mole frequency picker is editable.
		let leftArmCard = leftArmMoleCard()
		XCTAssertTrue(leftArmCard.waitForExistence(timeout: 3))

		let frequencyButton = firstMoleFrequencyButton()
		XCTAssertTrue(frequencyButton.waitForExistence(timeout: 3))
		XCTAssertTrue(frequencyButton.isEnabled)

		app.buttons["Disabled"].firstMatch.tap()
		XCTAssertFalse(firstMoleFrequencyButton().isEnabled)

		app.buttons["Enabled"].firstMatch.tap()
		XCTAssertTrue(firstMoleFrequencyButton().isEnabled)

		app.buttons["Follow Default"].firstMatch.tap()
		XCTAssertTrue(firstMoleFrequencyButton().isEnabled)
	}

	func testMoleFrequencySelectionPersistsAfterPersonSwitch() {
		// Verifies a mole frequency selection survives a person switch and return.
		XCTAssertTrue(app.staticTexts["Alex"].waitForExistence(timeout: 3))
		let leftArmCard = leftArmMoleCard()
		XCTAssertTrue(leftArmCard.waitForExistence(timeout: 3))

		let moleFrequency = firstMoleFrequencyButton()
		XCTAssertTrue(moleFrequency.waitForExistence(timeout: 3))
		moleFrequency.tap()
		app.buttons["Quarterly"].tap()

		XCTAssertEqual(firstMoleFrequencyButton().label, "Quarterly")

		nextPersonButton.tap()
		XCTAssertTrue(app.staticTexts["Jordan"].waitForExistence(timeout: 3))

		previousPersonButton.tap()
		XCTAssertTrue(app.staticTexts["Alex"].waitForExistence(timeout: 3))
		XCTAssertTrue(firstMoleFrequencyButton().waitForExistence(timeout: 3))
		XCTAssertEqual(firstMoleFrequencyButton().label, "Quarterly")
	}

	func testChangingDefaultFrequencyDoesNotOverrideCustomMoleFrequency() {
		// Verifies custom mole frequency stays independent from the person's default frequency.
		XCTAssertTrue(app.staticTexts["Alex"].waitForExistence(timeout: 3))
		let leftArmCard = leftArmMoleCard()
		XCTAssertTrue(leftArmCard.waitForExistence(timeout: 3))

		let moleFrequency = firstMoleFrequencyButton()
		XCTAssertTrue(moleFrequency.waitForExistence(timeout: 3))
		moleFrequency.tap()
		app.buttons["Quarterly"].tap()

		let defaultFrequency = defaultFrequencyButton()
		XCTAssertTrue(defaultFrequency.waitForExistence(timeout: 3))
		let targetDefaultFrequency = defaultFrequency.label == "Monthly" ? "Weekly" : "Monthly"
		defaultFrequency.tap()
		let targetOption = app.buttons[targetDefaultFrequency].firstMatch
		XCTAssertTrue(targetOption.waitForExistence(timeout: 3))
		targetOption.tap()

		XCTAssertEqual(firstMoleFrequencyButton().label, "Quarterly")
		XCTAssertEqual(defaultFrequencyButton().label, targetDefaultFrequency)
	}

	func testDueDateIsShownAsFormattedDateWhenPresent() {
		// Verifies moles with a due date render a formatted date string.
		let leftArmCard = leftArmMoleCard()
		XCTAssertTrue(leftArmCard.waitForExistence(timeout: 3))

		let dateLikeText = leftArmCard.staticTexts.matching(
			NSPredicate(format: "label MATCHES %@", ".*\\\\d{1,2}[:.]\\\\d{2}.*")
		).firstMatch

		XCTAssertTrue(dateLikeText.waitForExistence(timeout: 3))
		XCTAssertFalse(leftArmCard.staticTexts["No date set"].exists)
	}

	func testNoDateSetLabelShownForMoleWithoutDueDate() {
		// Verifies moles without a due date render the fallback label.
		XCTAssertTrue(app.staticTexts["Mole Back Mole"].waitForExistence(timeout: 3))
		XCTAssertTrue(app.staticTexts["No date set"].waitForExistence(timeout: 3))
	}

	func testUpcomingCheckinsAreSortedByDueDateWithNilDatesLast() {
		// Verifies the upcoming check-in list is ordered by due date with nil values last.
		let leftArm = app.staticTexts["Mole Left Arm Mole"]
		let back = app.staticTexts["Mole Back Mole"]

		XCTAssertTrue(leftArm.waitForExistence(timeout: 3))
		XCTAssertTrue(back.waitForExistence(timeout: 3))
		XCTAssertLessThan(leftArm.frame.minY, back.frame.minY)
	}

	// MARK: - Empty Store

	func testEmptyStoreShowsNoMolesMessage() {
		app.terminate()
		app.launchArguments.append("-UITest_EmptyStore")
		app.launch()
		app.tabBars.buttons["Reminder"].tap()

		XCTAssertTrue(app.staticTexts["No moles for this person"].waitForExistence(timeout: 3))
	}
}
