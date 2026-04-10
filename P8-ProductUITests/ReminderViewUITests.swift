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

	// MARK: - Empty Store

	func testEmptyStoreShowsNoMolesMessage() {
		app.terminate()
		app.launchArguments.append("-UITest_EmptyStore")
		app.launch()
		app.tabBars.buttons["Reminder"].tap()

		XCTAssertTrue(app.staticTexts["No moles for this person"].waitForExistence(timeout: 3))
	}
}
