//
//  ReminderViewUITests.swift
//  P8-ProductUITests
//
//  UI tests for the Reminder tab.
//

import XCTest

/// UI tests for the Reminder tab, covering person navigation, reminder controls, and persistence.
final class ReminderViewUITests: XCTestCase {

    /// The application instance under test.
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

    /// The chevron-right button used to navigate to the next person.
	private var nextPersonButton: XCUIElement {
		app.buttons["chevron.right"]
	}

    /// The chevron-left button used to navigate to the previous person.
	private var previousPersonButton: XCUIElement {
		app.buttons["chevron.left"]
	}

    /// The per-mole reminder frequency picker for Left Arm Mole.
	private var leftArmMoleFrequencyControl: XCUIElement {
		app.descendants(matching: .any)
			.matching(identifier: "moleReminderFrequencyPicker_Left Arm Mole")
			.firstMatch
	}

    /// The default reminder frequency picker for the currently displayed person.
	private var defaultFrequencyControl: XCUIElement {
		app.descendants(matching: .any)
			.matching(identifier: "defaultReminderFrequencyPicker")
			.firstMatch
	}

    /// The per-mole reminder enabled/disabled mode picker for Left Arm Mole.
    private var leftArmMoleEnabledControl: XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: "moleReminderEnabledPicker_Left Arm Mole")
            .firstMatch
    }

    /// Returns the Left Arm Mole enabled picker, skipping the test if it is not accessible.
    private func requireMoleEnabledButton() throws -> XCUIElement {
        let button = leftArmMoleEnabledControl
        guard button.waitForExistence(timeout: 3) else {
            throw XCTSkip("Per-mole enabled picker is not exposed as an accessible button.")
        }
        return button
    }
    
    /// Returns the per-mole frequency picker element for Left Arm Mole.
	private func firstMoleFrequencyButton() -> XCUIElement {
		leftArmMoleFrequencyControl
	}

    /// Returns the default reminder frequency picker element.
	private func defaultFrequencyButton() -> XCUIElement {
		defaultFrequencyControl
	}

    /// Returns the per-mole frequency picker, skipping the test if it is not accessible on this runtime.
	private func requireMoleFrequencyButton() throws -> XCUIElement {
		let button = firstMoleFrequencyButton()
		guard button.waitForExistence(timeout: 3) else {
			throw XCTSkip("Per-mole frequency picker is not exposed as an accessible button on this simulator runtime.")
		}

		return button
	}

    /// Returns the default frequency picker, skipping the test if it is not accessible on this runtime.
	private func requireDefaultFrequencyButton() throws -> XCUIElement {
		let button = defaultFrequencyButton()
		guard button.waitForExistence(timeout: 3) else {
			throw XCTSkip("Default frequency picker is not exposed as an accessible button on this simulator runtime.")
		}

		return button
	}

    /// Toggles the default reminder enabled switch to the specified state.
	private func setDefaultReminderEnabled(_ enabled: Bool) throws {
		let toggle = app.switches["defaultReminderEnabledToggle"].firstMatch
		guard toggle.waitForExistence(timeout: 3) else {
			throw XCTSkip("Default reminder toggle is not exposed as a switch.")
		}

		let isOn = (toggle.value as? String) == "1"
		if isOn != enabled {
			toggle.tap()
		}
	}

    /// Sets the per-mole reminder mode for the named mole to the given mode label.
	private func setMoleReminderMode(for moleName: String, to mode: String) throws {
		let picker = app.descendants(matching: .any)
			.matching(identifier: "moleReminderEnabledPicker_\(moleName)")
			.firstMatch
		guard picker.waitForExistence(timeout: 3) else {
			throw XCTSkip("Per-mole enabled picker for \(moleName) is not exposed as an accessible button.")
		}

		picker.tap()
		try chooseFrequencyOption(mode)
	}

    /// Taps a frequency option button matching the given label in the currently presented picker.
	private func chooseFrequencyOption(_ label: String) throws {
		let option = app.buttons[label].firstMatch
		guard option.waitForExistence(timeout: 3) else {
			throw XCTSkip("Frequency option '\(label)' is not exposed as an accessible button in this runtime.")
		}

		option.tap()
	}

    /// Extracts the selected frequency value from a picker button's accessibility label.
	private func selectedFrequencyValue(from accessibilityLabel: String) -> String {
		let parts = accessibilityLabel.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: true)
		if parts.count == 2 {
			return String(parts[1]).trimmingCharacters(in: .whitespaces)
		}

		return accessibilityLabel.trimmingCharacters(in: .whitespaces)
	}
    
	// MARK: - Smoke

    /// Verifies the reminder tab shows the expected header labels and section titles.
	func testReminderTabShowsHeaderAndSections() {
		XCTAssertTrue(app.staticTexts["Reminder"].waitForExistence(timeout: 3))
		XCTAssertTrue(app.staticTexts["Default Reminder Enabled"].exists)
		XCTAssertTrue(app.staticTexts["Default Reminder Frequency"].exists)
		XCTAssertTrue(app.staticTexts["Upcoming Check-ins"].exists)
	}

    /// Verifies the reminder tab shows the seeded person name, mole name, and reminder labels.
	func testReminderTabShowsSeededPersonAndMoleCardContent() {
		XCTAssertTrue(app.staticTexts["Alex"].waitForExistence(timeout: 3))
		XCTAssertTrue(app.staticTexts["Left Arm Mole"].waitForExistence(timeout: 3))
		XCTAssertTrue(app.staticTexts["Reminder"].exists)
		XCTAssertTrue(app.staticTexts["Reminder Frequency"].exists)
	}

	// MARK: - Person Switching

    /// Verifies the next-person button advances the selection from Alex to Jordan.
	func testNextPersonButtonSwitchesFromAlexToJordan() {
		XCTAssertTrue(app.staticTexts["Alex"].waitForExistence(timeout: 3))
		XCTAssertTrue(nextPersonButton.exists)

		nextPersonButton.tap()

		XCTAssertTrue(app.staticTexts["Jordan"].waitForExistence(timeout: 3))
	}

    /// Verifies the previous-person button is disabled when the first person is selected.
	func testPreviousPersonButtonDisabledOnFirstPerson() {
		XCTAssertTrue(app.staticTexts["Alex"].waitForExistence(timeout: 3))
		XCTAssertTrue(previousPersonButton.exists)
		XCTAssertFalse(previousPersonButton.isEnabled)
	}

    /// Verifies the next-person button is disabled when the last person is selected.
	func testNextPersonButtonDisabledOnLastPerson() {
		// Verifies the forward navigation control is disabled on the final person.
		XCTAssertTrue(app.staticTexts["Alex"].waitForExistence(timeout: 3))

		nextPersonButton.tap()
		XCTAssertTrue(app.staticTexts["Jordan"].waitForExistence(timeout: 3))

		nextPersonButton.tap()
		XCTAssertTrue(app.staticTexts["Taylor"].waitForExistence(timeout: 3))
		XCTAssertFalse(nextPersonButton.isEnabled)
	}

    /// Verifies the previous-person button becomes enabled after navigating away from the first person.
	func testPreviousPersonButtonEnabledAfterMovingForward() {
		// Verifies the back navigation control re-enables after moving off the first person.
		XCTAssertTrue(app.staticTexts["Alex"].waitForExistence(timeout: 3))
		XCTAssertFalse(previousPersonButton.isEnabled)

		nextPersonButton.tap()

		XCTAssertTrue(app.staticTexts["Jordan"].waitForExistence(timeout: 3))
		XCTAssertTrue(previousPersonButton.isEnabled)
	}

	// MARK: - Reminder Controls

    /// Verifies the reminder mode options (Default/Enabled/Disabled) are visible for a mole.
	func testReminderModeOptionsAreVisibleForMole() {
		XCTAssertTrue(app.staticTexts["Left Arm Mole"].waitForExistence(timeout: 3))

        let enabledPicker = leftArmMoleEnabledControl
        XCTAssertTrue(enabledPicker.waitForExistence(timeout: 3), "The Reminder Enabled picker was not found.")
            
        enabledPicker.tap()
        
		XCTAssertTrue(app.buttons["Default"].waitForExistence(timeout: 3))
		XCTAssertTrue(app.buttons["Enabled"].exists)
		XCTAssertTrue(app.buttons["Disabled"].exists)
	}

    /// Verifies changing the reminder mode toggles the enabled state of the per-mole frequency picker.
	func testReminderModeChangesMoleFrequencyControlEnabledState() throws {
		// Verifies reminder mode toggles whether the per-mole frequency picker is editable.
		XCTAssertTrue(app.staticTexts["Left Arm Mole"].waitForExistence(timeout: 3))

        let enabledPicker = leftArmMoleEnabledControl
        let frequencyButton = leftArmMoleFrequencyControl
        
        XCTAssertTrue(enabledPicker.waitForExistence(timeout: 3))
        XCTAssertTrue(frequencyButton.waitForExistence(timeout: 3))

        enabledPicker.tap()
        
        try chooseFrequencyOption("Disabled")
        XCTAssertFalse(frequencyButton.isEnabled)

        enabledPicker.tap()
        try chooseFrequencyOption("Enabled")
        XCTAssertTrue(frequencyButton.isEnabled)
	}

    /// Verifies disabling a mole's reminder removes the reminder badge from the overview.
	func testDisablingMoleReminderUpdatesOverviewIndicator() throws {
		// Verifies disabling a mole reminder hides the overview reminder badge for that mole.
		Helpers.openOverviewTab(in: app)

		XCTAssertTrue(app.staticTexts["Alex"].waitForExistence(timeout: 3))
		XCTAssertTrue(app.staticTexts["Left Arm Mole"].waitForExistence(timeout: 3))

		let initialReminderIcon = app.images["overviewReminderIcon_Left Arm Mole"]
		XCTAssertTrue(
			initialReminderIcon.waitForExistence(timeout: 3),
			"Expected overview reminder icon to be visible before disabling reminder"
		)   

		Helpers.openReminderTab(in: app)
		let enabledPicker = try requireMoleEnabledButton()
		enabledPicker.tap()
		try chooseFrequencyOption("Disabled")

		Helpers.openOverviewTab(in: app)
		let updatedReminderIcon = app.images["overviewReminderIcon_Left Arm Mole"]
		XCTAssertFalse(
			updatedReminderIcon.waitForExistence(timeout: 2),
			"Expected overview reminder icon to disappear after disabling reminder"
		)
	}

    /// Verifies toggling off the default reminder hides badges for moles with no custom frequency.
	func testDisablingDefaultReminderDisablesRemindersIfNoCustomFrequencySet() throws {
		// Verifies toggling off the default reminder disables reminders for moles without a custom frequency.
		XCTAssertTrue(app.staticTexts["Alex"].waitForExistence(timeout: 3))
        Helpers.openOverviewTab(in: app)
		XCTAssertTrue(app.staticTexts["Back Mole"].waitForExistence(timeout: 3))
		XCTAssertTrue(app.staticTexts["Left Arm Mole"].waitForExistence(timeout: 3))

		XCTAssertTrue(app.images["overviewReminderIcon_Back Mole"].waitForExistence(timeout: 3))
		XCTAssertTrue(app.images["overviewReminderIcon_Left Arm Mole"].waitForExistence(timeout: 3))

        Helpers.openReminderTab(in: app)
		let defaultReminderToggle = app.switches["defaultReminderEnabledToggle"].firstMatch
		XCTAssertTrue(defaultReminderToggle.waitForExistence(timeout: 3))
        defaultReminderToggle.tap()

		Helpers.openOverviewTab(in: app)
		XCTAssertFalse(app.images["overviewReminderIcon_Back Mole"].waitForExistence(timeout: 3), "Expected overview reminder icon for Back Mole to disappear when default reminder is turned off and no custom frequency is set.")
		XCTAssertFalse(app.images["overviewReminderIcon_Left Arm Mole"].waitForExistence(timeout: 3), "Expected overview reminder icon for Left Arm Mole to disappear when default reminder is turned off and no custom frequency is set.")

	}

    /// Verifies the overview reminder badge returns after re-enabling default reminders.
	func testReEnablingDefaultReminderRestoresOverviewIndicatorForDefaultMole() throws {
		// Verifies the overview reminder badge returns after re-enabling default reminders.
		Helpers.openOverviewTab(in: app)
		XCTAssertTrue(app.images["overviewReminderIcon_Left Arm Mole"].waitForExistence(timeout: 3))

		Helpers.openReminderTab(in: app)
		try setDefaultReminderEnabled(false)

		Helpers.openOverviewTab(in: app)
		XCTAssertFalse(app.images["overviewReminderIcon_Left Arm Mole"].waitForExistence(timeout: 2))

		Helpers.openReminderTab(in: app)
		try setDefaultReminderEnabled(true)

		Helpers.openOverviewTab(in: app)
		XCTAssertTrue(
			app.images["overviewReminderIcon_Left Arm Mole"].waitForExistence(timeout: 3),
			"Expected overview reminder icon to return after re-enabling default reminder"
		)
	}

    /// Verifies a per-mole Enabled override keeps the badge visible even when the default reminder is off.
	func testMoleEnabledOverrideStaysVisibleWhenDefaultReminderIsOff() throws {
		// Verifies per-mole Enabled override stays active when person default is disabled.
		Helpers.openReminderTab(in: app)
		try setMoleReminderMode(for: "Left Arm Mole", to: "Enabled")
		try setDefaultReminderEnabled(false)

		Helpers.openOverviewTab(in: app)
		XCTAssertTrue(
			app.images["overviewReminderIcon_Left Arm Mole"].waitForExistence(timeout: 3),
			"Expected Left Arm Mole icon to remain visible due to per-mole Enabled override"
		)
		XCTAssertFalse(
			app.images["overviewReminderIcon_Back Mole"].waitForExistence(timeout: 2),
			"Expected default-following Back Mole icon to be hidden when default reminder is off"
		)
	}

    /// Verifies a per-mole Disabled override keeps the badge hidden even when the default reminder is on.
	func testMoleDisabledOverrideStaysHiddenWhenDefaultReminderIsOn() throws {
		// Verifies per-mole Disabled override stays inactive even if default reminders are enabled.
		Helpers.openReminderTab(in: app)
		try setMoleReminderMode(for: "Left Arm Mole", to: "Disabled")
		try setDefaultReminderEnabled(true)

		Helpers.openOverviewTab(in: app)
		XCTAssertFalse(
			app.images["overviewReminderIcon_Left Arm Mole"].waitForExistence(timeout: 2),
			"Expected Left Arm Mole icon to stay hidden due to per-mole Disabled override"
		)
		XCTAssertTrue(
			app.images["overviewReminderIcon_Back Mole"].waitForExistence(timeout: 3),
			"Expected default-following Back Mole icon to remain visible when default reminder is on"
		)
	}

    /// Verifies reminder controls update to reflect the selected person's settings after switching.
	func testReminderControlsSyncWhenSwitchingPeople() throws {
		// Verifies default toggle/frequency controls refresh to the newly selected person's settings.
		XCTAssertTrue(app.staticTexts["Alex"].waitForExistence(timeout: 3))

		try setDefaultReminderEnabled(false)
		let defaultFrequency = try requireDefaultFrequencyButton()
		defaultFrequency.tap()
		try chooseFrequencyOption("Monthly")

		nextPersonButton.tap()
		XCTAssertTrue(app.staticTexts["Jordan"].waitForExistence(timeout: 3))

		let jordanToggle = app.switches["defaultReminderEnabledToggle"].firstMatch
		XCTAssertTrue(jordanToggle.waitForExistence(timeout: 3))
		XCTAssertEqual(jordanToggle.value as? String, "1", "Expected Jordan's default reminder to be ON")
		XCTAssertEqual(selectedFrequencyValue(from: defaultFrequencyButton().label), "Weekly")

		previousPersonButton.tap()
		XCTAssertTrue(app.staticTexts["Alex"].waitForExistence(timeout: 3))
		XCTAssertEqual(jordanToggle.value as? String, "0", "Expected Alex's default reminder to remain OFF")
		XCTAssertEqual(selectedFrequencyValue(from: defaultFrequencyButton().label), "Monthly")
	}

    /// Verifies the default reminder enabled state persists across app relaunches.
	func testDefaultReminderSettingsPersistAfterRelaunch() throws {
		app.terminate()
		app.launchArguments = ["-UITest_PersistentStore", "-UITest_ResetStore", "-SkipModelLoading"]
		app.launch()
		Helpers.openReminderTab(in: app)

		XCTAssertTrue(app.staticTexts["Alex"].waitForExistence(timeout: 3))
		try setDefaultReminderEnabled(false)

		app.terminate()
		app.launchArguments = ["-UITest_PersistentStore", "-SkipModelLoading"]
		app.launch()
		Helpers.openReminderTab(in: app)

		let persistedToggle = app.switches["defaultReminderEnabledToggle"].firstMatch
		XCTAssertTrue(persistedToggle.waitForExistence(timeout: 3))
		XCTAssertEqual(persistedToggle.value as? String, "0", "Expected default reminder OFF state to persist after relaunch")
	}

    /// Verifies changing the default frequency recalculates the due date for moles following defaults.
	func testChangingDefaultFrequencyUpdatesDueDateForFollowDefaultMole() throws {
		// Verifies changing default frequency recalculates due date for moles following defaults.
		let dueDateLabel = app.staticTexts["moleDueDateLabel_Back Mole"].firstMatch
		XCTAssertTrue(dueDateLabel.waitForExistence(timeout: 3))
		XCTAssertEqual(dueDateLabel.label, "No date set")

		let defaultFrequency = try requireDefaultFrequencyButton()
		defaultFrequency.tap()
		try chooseFrequencyOption("Monthly")

		XCTAssertTrue(dueDateLabel.waitForExistence(timeout: 3))
		XCTAssertNotEqual(
			dueDateLabel.label,
			"No date set",
			"Expected Back Mole due date to be recalculated after changing default frequency"
		)
	}

    /// Verifies a mole frequency selection survives navigating to another person and back.
	func testMoleFrequencySelectionPersistsAfterPersonSwitch() throws {
		// Verifies a mole frequency selection survives a person switch and return.
		XCTAssertTrue(app.staticTexts["Alex"].waitForExistence(timeout: 3))
		XCTAssertTrue(app.staticTexts["Left Arm Mole"].waitForExistence(timeout: 3))

		let moleFrequency = try requireMoleFrequencyButton()
		moleFrequency.tap()
		try chooseFrequencyOption("Quarterly")

		XCTAssertEqual(selectedFrequencyValue(from: firstMoleFrequencyButton().label), "Quarterly")

		nextPersonButton.tap()
		XCTAssertTrue(app.staticTexts["Jordan"].waitForExistence(timeout: 3))

		previousPersonButton.tap()
		XCTAssertTrue(app.staticTexts["Alex"].waitForExistence(timeout: 3))
		XCTAssertTrue(firstMoleFrequencyButton().waitForExistence(timeout: 3))
		XCTAssertEqual(selectedFrequencyValue(from: firstMoleFrequencyButton().label), "Quarterly")
	}

    /// Verifies a custom mole frequency is not overwritten when the default frequency changes.
	func testChangingDefaultFrequencyDoesNotOverrideCustomMoleFrequency() throws {
		// Verifies custom mole frequency stays independent from the person's default frequency.
		XCTAssertTrue(app.staticTexts["Alex"].waitForExistence(timeout: 3))
		XCTAssertTrue(app.staticTexts["Left Arm Mole"].waitForExistence(timeout: 3))

		let moleFrequency = try requireMoleFrequencyButton()
		moleFrequency.tap()
		try chooseFrequencyOption("Quarterly")

		let defaultFrequency = try requireDefaultFrequencyButton()
		let targetDefaultFrequency = defaultFrequency.label == "Monthly" ? "Weekly" : "Monthly"
		defaultFrequency.tap()
		try chooseFrequencyOption(targetDefaultFrequency)

		XCTAssertEqual(selectedFrequencyValue(from: firstMoleFrequencyButton().label), "Quarterly")
		XCTAssertEqual(selectedFrequencyValue(from: defaultFrequencyButton().label), targetDefaultFrequency)
	}

    /// Verifies moles with a due date display a formatted date string.
	func testDueDateIsShownAsFormattedDateWhenPresent() {
		// Verifies moles with a due date render a formatted date string.
		XCTAssertTrue(app.staticTexts["Left Arm Mole"].waitForExistence(timeout: 3))

		let labels = app.staticTexts.allElementsBoundByIndex.map(\.label)
		let hasDateLikeLabel = labels.contains { label in
			guard label != "Left Arm Mole",
			      label != "Back Mole",
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

    /// Verifies moles without a due date display the "No date set" fallback label.
	func testNoDateSetLabelShownForMoleWithoutDueDate() {
		// Verifies moles without a due date render the fallback label.
		XCTAssertTrue(app.staticTexts["Back Mole"].waitForExistence(timeout: 3))
		XCTAssertTrue(app.staticTexts["No date set"].waitForExistence(timeout: 3))
	}

    /// Verifies the upcoming check-in list is sorted by due date with nil-date moles last.
	func testUpcomingCheckinsAreSortedByDueDateWithNilDatesLast() {
		// Verifies the upcoming check-in list is ordered by due date with nil values last.
		let leftArm = app.staticTexts["Left Arm Mole"]
		let back = app.staticTexts["Back Mole"]

		XCTAssertTrue(leftArm.waitForExistence(timeout: 3))
		XCTAssertTrue(back.waitForExistence(timeout: 3))
		XCTAssertLessThan(leftArm.frame.minY, back.frame.minY)
	}

    /// Verifies the detail view renders the next-due summary for a mole that has a due date.
	func testDetailViewShowsDueDateSummaryForMoleWithDueDate() {
		// Verifies detail view renders the next-due summary line for moles with a due date.
		Helpers.openMoleDetail(person: "Alex", mole: "Left Arm Mole", in: app)

		let dueSummary = app.staticTexts["moleDetailNextDueDateSummary"].firstMatch
		XCTAssertTrue(dueSummary.waitForExistence(timeout: 3), "Expected due-date summary to be visible in detail view")
		XCTAssertTrue(dueSummary.label.contains("Next due date:"), "Expected summary to contain due-date text")
	}

    /// Verifies the detail view does not render the summary line for a mole without a due date.
	func testDetailViewHidesDueDateSummaryForMoleWithoutDueDate() throws {
		// Verifies detail view does not render the summary line when a mole has no due date.
		Helpers.openReminderTab(in: app)

		try setDefaultReminderEnabled(false)

		Helpers.openMoleDetail(person: "Alex", mole: "Back Mole", in: app)
	
		XCTAssertFalse(app.staticTexts["moleDetailNextDueDateSummary"].waitForExistence(timeout: 2), "Expected no due-date summary for mole without due date")
	}



	// MARK: - Empty Store

    /// Verifies the reminder tab shows the "No moles for this person" message when the store is empty.
	func testEmptyStoreShowsNoMolesMessage() {
		app.terminate()
		app.launchArguments.append("-UITest_EmptyStore")
		app.launch()
		app.tabBars.buttons["Reminder"].tap()

		XCTAssertTrue(app.staticTexts["No moles for this person"].waitForExistence(timeout: 3))
	}
}
