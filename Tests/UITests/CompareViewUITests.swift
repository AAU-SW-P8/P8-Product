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
        app.launchArguments.append("-SkipModelLoading")
        app.launchArguments.append("-UITest_InMemoryStore")
        app.launch()

        // Navigate to the Compare tab
        Helpers.openCompareTab(in: app)
    }

    // MARK: - Navigation & Title

    func testCompareTabShowsTitle() {
        XCTAssertTrue(app.staticTexts["Compare"].waitForExistence(timeout: 3),
                      "Compare tab should show title 'Compare'")
    }

    // MARK: - Empty Store

    func testEmptyStateShownWhenNoPeopleExist() {
        // Re-launch with the empty-store flag so the seeded mock data is skipped.
        app.terminate()
        app.launchArguments.append("-UITest_EmptyStore")
        app.launchArguments.append("-SkipModelLoading")
        app.launch()
        Helpers.openCompareTab(in: app)

        XCTAssertTrue(
            app.staticTexts["emptyStateTitle"].waitForExistence(timeout: 3),
            "Empty state title should appear when there are no people"
        )
        XCTAssertTrue(
            app.staticTexts["emptyStateMessage"].exists,
            "Empty state message should appear when there are no people"
        )
        XCTAssertFalse(
            app.otherElements["selectorBar"].exists,
            "Selector bar should be hidden when people is empty"
        )
    }

    // MARK: - Initial State (no selection)

    func testInitialStateShowsSelectPersonPrompt() {
        Helpers.selectPerson("Select Person", in: app)
        let prompt = app.staticTexts["selectPersonPrompt"]
        XCTAssertTrue(prompt.waitForExistence(timeout: 3),
                       "Should show 'Select a person' when no person is selected")
    }

    func testPersonPickerIsVisible() {
        XCTAssertTrue(Helpers.personPickerButton(in: app).waitForExistence(timeout: 3),
                       "Person picker should be visible on Compare tab")
    }

    // MARK: - Person Selection

    func testSelectingPersonShowsMolePromptAndPicker() {
        Helpers.selectPerson("Alex", in: app)

        let prompt = app.staticTexts["selectMolePrompt"]
        XCTAssertTrue(prompt.waitForExistence(timeout: 3),
                       "Should show 'Select a mole' after picking a person")
    }

    func testSelectingPersonWithNoScansShowsMakeScanMessage() {
        // Taylor only has one mole with no scans in the mock data.
        Helpers.selectPerson("Taylor", in: app)

        let message = app.staticTexts["makeScanBeforeCompareMessage"]
        XCTAssertTrue(message.waitForExistence(timeout: 3),
                       "Should prompt to make a scan if selected person has no scans")
    }

    func testSelectingPersonShowsMolePicker() {
        Helpers.selectPerson("Alex", in: app)

        XCTAssertTrue(Helpers.molePickerButton(in: app).waitForExistence(timeout: 3),
                       "Mole picker should appear after a person is selected")
    }

    // MARK: - Mole Selection → Dual Carousel (multiple scans)

    func testSelectingMoleWithMultipleScansShowsDualCarouselAndMetricPicker() {
        // Alex's "Left Arm Mole" has 3 scans → dual carousel + metric picker
        Helpers.selectPerson("Alex", in: app)
        Helpers.selectMole("Left Arm Mole", in: app)

        let container = app.otherElements["dualCarouselContainer"]
        XCTAssertTrue(container.waitForExistence(timeout: 5),
                       "Dual carousel should appear for a mole with multiple scans")
        XCTAssertTrue(app.segmentedControls["metricPicker"].exists,
                       "Metric picker should appear when a mole with scans is selected")
    }

    // MARK: - Switching Person Resets Mole

    func testSwitchingPersonResetsMoleSelection() {
        Helpers.selectPerson("Alex", in: app)
        Helpers.selectMole("Left Arm Mole", in: app)

        XCTAssertTrue(app.otherElements["dualCarouselContainer"].waitForExistence(timeout: 5))

        // After selecting Alex the picker label may change to "Alex" instead of
        // containing "Person", so match on the selected name.
        Helpers.selectPerson("Jordan", in: app)
        let prompt = app.staticTexts["selectMolePrompt"]
        XCTAssertTrue(prompt.waitForExistence(timeout: 3),
                          "Should show 'Select a mole' after switching to a different person")
                          
    }

    // MARK: - Single Scan Mole

    func testSelectingMoleWithSingleScanShowsSingleCarousel() {
        // Alex's "Back Mole" has only 1 scan → single carousel, no chart
        Helpers.selectPerson("Alex", in: app)
        Helpers.selectMole("Back Mole", in: app)

        let dualContainer = app.otherElements["dualCarouselContainer"]
        XCTAssertFalse(dualContainer.waitForExistence(timeout: 2),
                        "Single-scan mole should not show dual carousel")

        let metricPicker = app.segmentedControls["metricPicker"]
        XCTAssertFalse(metricPicker.exists,
                        "Single-scan mole should not show metric picker")
    }

    // MARK: - Mock Container Data Verification
    //
    // The following tests assert that every value seeded by `MockData.insertSampleData`
    // is surfaced correctly in CompareView. The mock data contains:
    //   • Person "Alex"   → Mole "Left Arm Mole" (Left Arm) with 3 scans
    //                                  diameters 4.2 / 4.8 / 5.0 mm
    //                                  areas     13.8 / 15.4 / 16.0 mm²
    //                       Mole "Back Mole"     (Back) with 1 scan
    //                                  diameter  3.6 mm, area 10.1 mm²
    //   • Person "Jordan" → Mole "Face Mole"     (Face) with 1 scan
    //                                  diameter  2.9 mm, area 6.6 mm²
    //
    // For the multi-scan mole, scans are sorted ascending by capture date,
    // so the carousel's first frame corresponds to the oldest scan
    // (60 days ago: diameter 5.0 mm, area 16.0 mm²).

    func testPersonPickerContainsAllMockedPeople() {
        Helpers.personPickerButton(in: app).tap()

        XCTAssertTrue(app.buttons["Alex"].waitForExistence(timeout: 3),
                       "Person picker should contain Alex from mock data")
        XCTAssertTrue(app.buttons["Jordan"].exists,
                       "Person picker should contain Jordan from mock data")
    }

    func testMolePickerContainsAllMockedMolesForAlex() {
        Helpers.selectPerson("Alex", in: app)

        Helpers.molePickerButton(in: app).tap()

        // Body parts in mock data for Alex are "Left Arm" and "Back".
        // SwiftUI Menu sections render their titles as static text.
        XCTAssertTrue(app.buttons["Left Arm Mole"].waitForExistence(timeout: 3),
                       "Alex's mole picker should contain Left Arm Mole")
        XCTAssertTrue(app.buttons["Back Mole"].exists,
                       "Alex's mole picker should contain Back Mole")
        XCTAssertTrue(app.staticTexts["Left Arm"].exists,
                       "Mole picker should show 'Left Arm' body part section")
        XCTAssertTrue(app.staticTexts["Back"].exists,
                       "Mole picker should show 'Back' body part section")
    }

    func testMolePickerContainsAllMockedMolesForJordan() {
        Helpers.selectPerson("Jordan", in: app)

        // Jordan only has one mole, so the mole picker label is "Select Mole".
        Helpers.molePickerButton(in: app).tap()

        XCTAssertTrue(app.buttons["Face Mole"].waitForExistence(timeout: 3),
                       "Jordan's mole picker should contain Face Mole")
        XCTAssertTrue(app.staticTexts["Face"].exists,
                       "Mole picker should show 'Face' body part section for Jordan")
    }

    func testLeftArmMoleShowsFirstScanDiameterAndArea() {
        // Sorted by capture date, the first scan for Left Arm Mole is alexScan4
        // (60 days ago) with diameter 5.0 mm and area 16.0 mm².
        Helpers.selectPerson("Alex", in: app)
        Helpers.selectMole("Left Arm Mole", in: app)

        XCTAssertTrue(app.otherElements["dualCarouselContainer"].waitForExistence(timeout: 5))

        XCTAssertTrue(
            app.staticTexts["Diameter: 5.0 mm"].firstMatch.waitForExistence(timeout: 3)
            || app.staticTexts["Diameter: 5,0 mm"].firstMatch.waitForExistence(timeout: 3),
            "Carousel should display diameter 5.0/5,0 mm for the first Left Arm scan"
        )
        XCTAssertTrue(
            app.staticTexts["Area: 16.0 mm²"].firstMatch.exists
            || app.staticTexts["Area: 16,0 mm²"].firstMatch.exists,
            "Carousel should display area 16.0/16,0 mm² for the first Left Arm scan"
        )
    }

    func testBackMoleShowsCorrectDiameterAndArea() {
        // Back Mole has a single scan with diameter 3.6 mm and area 10.1 mm².
        Helpers.selectPerson("Alex", in: app)
        Helpers.selectMole("Back Mole", in: app)

        XCTAssertTrue(
            app.staticTexts["Diameter: 3.6 mm"].firstMatch.waitForExistence(timeout: 5)
            || app.staticTexts["Diameter: 3,6 mm"].firstMatch.waitForExistence(timeout: 5),
            "Carousel should display diameter 3.6/3,6 mm for Back Mole"
        )
        XCTAssertTrue(
            app.staticTexts["Area: 10.1 mm²"].firstMatch.exists
            || app.staticTexts["Area: 10,1 mm²"].firstMatch.exists,
            "Carousel should display area 10.1/10,1 mm² for Back Mole"
        )
    }

    func testFaceMoleShowsCorrectDiameterAndAreaForJordan() {
        // Face Mole has a single scan with diameter 2.9 mm and area 6.6 mm².
        Helpers.selectPerson("Jordan", in: app)
        Helpers.selectMole("Face Mole", in: app)

        XCTAssertTrue(
            app.staticTexts["Diameter: 2.9 mm"].firstMatch.waitForExistence(timeout: 5)
            || app.staticTexts["Diameter: 2,9 mm"].firstMatch.waitForExistence(timeout: 5),
            "Carousel should display diameter 2.9/2,9 mm for Face Mole"
        )
        XCTAssertTrue(
            app.staticTexts["Area: 6.6 mm²"].firstMatch.exists
            || app.staticTexts["Area: 6,6 mm²"].firstMatch.exists,
            "Carousel should display area 6.6/6,6 mm² for Face Mole"
        )
    }

    func testLeftArmMoleAreaTrendEvolutionMatchesMockData() {
        // Areas sorted by date: 16.0 → 13.8 → 15.4 → evolution = 15.4 - 16.0 = -0.6 mm²
        Helpers.selectPerson("Alex", in: app)
        Helpers.selectMole("Left Arm Mole", in: app)

        XCTAssertTrue(app.staticTexts["Area Trend"].waitForExistence(timeout: 5),
                       "Chart should default to Area Trend")
        XCTAssertTrue(
            app.staticTexts["-0.6 mm²"].exists || app.staticTexts["-0,6 mm²"].exists,
            "Area Trend evolution should be -0.6/-0,6 mm² for the seeded Left Arm scans"
        )
    }

    func testLeftArmMoleDiameterTrendEvolutionMatchesMockData() {
        // Diameters sorted by date: 5.0 → 4.2 → 4.8 → evolution = 4.8 - 5.0 = -0.2 mm
        Helpers.selectPerson("Alex", in: app)
        Helpers.selectMole("Left Arm Mole", in: app)

        let picker = app.segmentedControls["metricPicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.buttons["Diameter"].tap()

        XCTAssertTrue(app.staticTexts["Diameter Trend"].waitForExistence(timeout: 3),
                       "Chart should switch to Diameter Trend")
        XCTAssertTrue(
            app.staticTexts["-0.2 mm"].exists || app.staticTexts["-0,2 mm"].exists,
            "Diameter Trend evolution should be -0.2/-0,2 mm for the seeded Left Arm scans"
        )
    }

    // Note: per-point chart annotations are not reliably queryable from XCUI
    // because Swift Charts hosts annotation views inside an opaque backing
    // element. Per-point data flow is instead verified by the unit tests in
    // `Tests/PipelineTests/ChartViewDataTests.swift`, which exercise
    // `ChartView.makeChartData(for:metric:)` directly.
}
