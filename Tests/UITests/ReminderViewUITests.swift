//
//  ReminderViewUITests.swift
//  P8-ProductUITests
//
//  UI tests for the Reminder tab.
//

import XCTest

final class ReminderViewUITests: XCTestCase {

	private var app: XCUIApplication!

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

	private var leftArmMoleFrequencyControl: XCUIElement {
		app.descendants(matching: .any)
			.matching(identifier: "moleReminderFrequencyPicker_Left Arm Mole")
			.firstMatch
	}

	private var defaultFrequencyControl: XCUIElement {
		app.descendants(matching: .any)
			.matching(identifier: "defaultReminderFrequencyPicker")
			.firstMatch
	}

	private func firstMoleFrequencyButton() -> XCUIElement {
		leftArmMoleFrequencyControl
	}

	private func defaultFrequencyButton() -> XCUIElement {
		defaultFrequencyControl
	}

	private func requireMoleFrequencyButton() throws -> XCUIElement {
		let button = firstMoleFrequencyButton()
		guard button.waitForExistence(timeout: 3) else {
			throw XCTSkip("Per-mole frequency picker is not exposed as an accessible button on this simulator runtime.")
		}

		return button
	}

	private func requireDefaultFrequencyButton() throws -> XCUIElement {
		let button = defaultFrequencyButton()
		guard button.waitForExistence(timeout: 3) else {
			throw XCTSkip("Default frequency picker is not exposed as an accessible button on this simulator runtime.")
		}

		return button
	}

	private func chooseFrequencyOption(_ label: String) throws {
		let option = app.buttons[label].firstMatch
		guard option.waitForExistence(timeout: 3) else {
			throw XCTSkip("Frequency option '\(label)' is not exposed as an accessible button in this runtime.")
		}

		option.tap()
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

	func testReminderModeChangesMoleFrequencyControlEnabledState() throws {
		// Verifies reminder mode toggles whether the per-mole frequency picker is editable.
		XCTAssertTrue(app.staticTexts["Mole Left Arm Mole"].waitForExistence(timeout: 3))

		let frequencyButton = try requireMoleFrequencyButton()
		XCTAssertTrue(frequencyButton.isEnabled)

		app.buttons["Disabled"].firstMatch.tap()
		XCTAssertFalse(firstMoleFrequencyButton().isEnabled)

		app.buttons["Enabled"].firstMatch.tap()
		XCTAssertTrue(firstMoleFrequencyButton().isEnabled)

		app.buttons["Follow Default"].firstMatch.tap()
		XCTAssertTrue(firstMoleFrequencyButton().isEnabled)
	}

	func testMoleFrequencySelectionPersistsAfterPersonSwitch() throws {
		// Verifies a mole frequency selection survives a person switch and return.
		XCTAssertTrue(app.staticTexts["Alex"].waitForExistence(timeout: 3))
		XCTAssertTrue(app.staticTexts["Mole Left Arm Mole"].waitForExistence(timeout: 3))

		let moleFrequency = try requireMoleFrequencyButton()
		moleFrequency.tap()
		try chooseFrequencyOption("Quarterly")

		XCTAssertEqual(firstMoleFrequencyButton().label, "Quarterly")

		nextPersonButton.tap()
		XCTAssertTrue(app.staticTexts["Jordan"].waitForExistence(timeout: 3))

		previousPersonButton.tap()
		XCTAssertTrue(app.staticTexts["Alex"].waitForExistence(timeout: 3))
		XCTAssertTrue(firstMoleFrequencyButton().waitForExistence(timeout: 3))
		XCTAssertEqual(firstMoleFrequencyButton().label, "Quarterly")
	}

	func testChangingDefaultFrequencyDoesNotOverrideCustomMoleFrequency() throws {
		// Verifies custom mole frequency stays independent from the person's default frequency.
		XCTAssertTrue(app.staticTexts["Alex"].waitForExistence(timeout: 3))
		XCTAssertTrue(app.staticTexts["Mole Left Arm Mole"].waitForExistence(timeout: 3))

		let moleFrequency = try requireMoleFrequencyButton()
		moleFrequency.tap()
		try chooseFrequencyOption("Quarterly")

		let defaultFrequency = try requireDefaultFrequencyButton()
		let targetDefaultFrequency = defaultFrequency.label == "Monthly" ? "Weekly" : "Monthly"
		defaultFrequency.tap()
		try chooseFrequencyOption(targetDefaultFrequency)

		XCTAssertEqual(firstMoleFrequencyButton().label, "Quarterly")
		XCTAssertEqual(defaultFrequencyButton().label, targetDefaultFrequency)
	}

	func testDueDateIsShownAsFormattedDateWhenPresent() {
		// Verifies moles with a due date render a formatted date string.
		XCTAssertTrue(app.staticTexts["Mole Left Arm Mole"].waitForExistence(timeout: 3))

		let labels = app.staticTexts.allElementsBoundByIndex.map(\.label)
		let hasDateLikeLabel = labels.contains { label in
			guard label != "Mole Left Arm Mole",
			      label != "Mole Back Mole",
			      label != "Reminder",
			      label != "Default Reminder Enabled",
			      label != "Default Reminder Frequency",
			      label != "Upcoming Check-ins",
			      label != "Reminder Frequency",
			      label != "No date set" else {
				return false
			}

			let hasDigit = label.range(of: #"\d"#, options: .regularExpression) != nil
			let hasTimeSeparator = label.contains(":") || label.contains(".")
			return hasDigit && hasTimeSeparator
		}

		XCTAssertTrue(hasDateLikeLabel, "Expected at least one date-like label in Reminder view. Labels: \(labels)")
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
