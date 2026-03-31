//
//  CompareViewUITests.swift
//  P8-ProductUITests
//
//  Tests for the CompareView tab, covering navigation,
//  selection flows, and content display states.
//

import XCTest

final class CompareViewUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()

        // Navigate to the Compare tab
        app.tabBars.buttons["Compare"].tap()
    }

    /// Finds the person picker button regardless of its current selection state.
    /// SwiftUI menu-style Pickers render as buttons whose label includes the Picker's label.
    private var personPickerButton: XCUIElement {
        app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Person")
        ).firstMatch
    }

    /// Finds the mole picker button. SwiftUI Menu doesn't reliably expose
    /// accessibilityIdentifier, so we match on the label text instead.
    private var molePickerButton: XCUIElement {
        app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Select Mole")
        ).firstMatch
    }

    // MARK: - Navigation & Title

    func testCompareTabShowsTitle() {
        XCTAssertTrue(app.staticTexts["Compare"].waitForExistence(timeout: 3))
    }

    // MARK: - Initial State (no selection)

    func testInitialStateShowsSelectPersonPrompt() {
        let prompt = app.staticTexts["selectPersonPrompt"]
        XCTAssertTrue(prompt.waitForExistence(timeout: 3),
                       "Should show 'Select a person' when no person is selected")
    }

    func testPersonPickerIsVisible() {
        XCTAssertTrue(personPickerButton.waitForExistence(timeout: 3),
                       "Person picker should be visible on Compare tab")
    }

    // MARK: - Person Selection

    func testSelectingPersonShowsSelectMolePrompt() {
        personPickerButton.tap()
        app.buttons["Alex"].tap()

        let prompt = app.staticTexts["selectMolePrompt"]
        XCTAssertTrue(prompt.waitForExistence(timeout: 3),
                       "Should show 'Select a mole' after picking a person")
    }

    func testSelectingPersonShowsMolePicker() {
        personPickerButton.tap()
        app.buttons["Alex"].tap()

        let molePicker = molePickerButton
        XCTAssertTrue(molePicker.waitForExistence(timeout: 3),
                       "Mole picker should appear after a person is selected")
    }

    // MARK: - Mole Selection → Dual Carousel (multiple scans)

    func testSelectingMoleWithMultipleScansShowsDualCarousel() {
        // Alex's "Left Arm Mole" has 3 scans → dual carousel
        personPickerButton.tap()
        app.buttons["Alex"].tap()

        molePickerButton.tap()
        app.buttons["Left Arm Mole"].tap()

        let container = app.otherElements["dualCarouselContainer"]
        XCTAssertTrue(container.waitForExistence(timeout: 5),
                       "Dual carousel should appear for a mole with multiple scans")
    }

    func testSelectingMoleWithMultipleScansShowsMetricPicker() {
        personPickerButton.tap()
        app.buttons["Alex"].tap()

        molePickerButton.tap()
        app.buttons["Left Arm Mole"].tap()

        let picker = app.segmentedControls["metricPicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5),
                       "Metric picker should appear when a mole with scans is selected")
    }

    // MARK: - Metric Picker Interaction

    func testSwitchingMetricToDiameter() {
        personPickerButton.tap()
        app.buttons["Alex"].tap()

        molePickerButton.tap()
        app.buttons["Left Arm Mole"].tap()

        let picker = app.segmentedControls["metricPicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))

        picker.buttons["Diameter"].tap()

        let trendLabel = app.staticTexts["Diameter Trend"]
        XCTAssertTrue(trendLabel.waitForExistence(timeout: 3),
                       "Chart should show 'Diameter Trend' after switching metric")
    }

    func testAreaMetricIsDefaultSelected() {
        personPickerButton.tap()
        app.buttons["Alex"].tap()

        molePickerButton.tap()
        app.buttons["Left Arm Mole"].tap()

        let trendLabel = app.staticTexts["Area Trend"]
        XCTAssertTrue(trendLabel.waitForExistence(timeout: 5),
                       "Chart should default to showing 'Area Trend'")
    }

    // MARK: - Switching Person Resets Mole

    func testSwitchingPersonResetsMoleSelection() {
        personPickerButton.tap()
        app.buttons["Alex"].tap()

        molePickerButton.tap()
        app.buttons["Left Arm Mole"].tap()

        XCTAssertTrue(app.otherElements["dualCarouselContainer"].waitForExistence(timeout: 5))

        // After selecting Alex the picker label may change to "Alex" instead of
        // containing "Person", so match on the selected name.
        let pickerAfterSelection = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Alex")
        ).firstMatch
        XCTAssertTrue(pickerAfterSelection.waitForExistence(timeout: 3))
        pickerAfterSelection.tap()
        app.buttons["Jordan"].tap()

        let prompt = app.staticTexts["selectMolePrompt"]
        XCTAssertTrue(prompt.waitForExistence(timeout: 3),
                       "Switching person should reset mole selection")
    }

    // MARK: - Single Scan Mole

    func testSelectingMoleWithSingleScanShowsSingleCarousel() {
        // Alex's "Back Mole" has only 1 scan → single carousel, no chart
        personPickerButton.tap()
        app.buttons["Alex"].tap()

        molePickerButton.tap()
        app.buttons["Back Mole"].tap()

        let dualContainer = app.otherElements["dualCarouselContainer"]
        XCTAssertFalse(dualContainer.waitForExistence(timeout: 2),
                        "Single-scan mole should not show dual carousel")

        let metricPicker = app.segmentedControls["metricPicker"]
        XCTAssertFalse(metricPicker.exists,
                        "Single-scan mole should not show metric picker")
    }
}
