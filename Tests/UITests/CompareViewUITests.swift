//
//  CompareViewUITests.swift
//  P8-ProductUITests
//
//  Tests for the new Mole Detail flow where users switch
//  between Detail and Evolution pages inside detail.
//

import XCTest


/// UI tests for the mole detail flow covering Detail/Evolution navigation, mole switching, and mock data verification.
final class MoleDetailFlowUITests: XCTestCase {

    /// The application instance under test.
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("-SkipModelLoading")
        app.launchArguments.append("-UITest_InMemoryStore")
        app.launch()

        Helpers.openOverviewTab(in: app)
    }

    // MARK: - Detail Navigation

    /// Verifies opening a mole shows the Detail/Evolution page picker.
    func testOpeningMoleShowsDetailPagePicker() {
        Helpers.openMoleDetail(person: "Alex", mole: "Left Arm Mole", in: app)

        let picker = app.segmentedControls["moleDetailPagePicker"]
        XCTAssertTrue(picker.exists, "Detail flow should show the Detail/Evolution page picker")
        XCTAssertTrue(picker.buttons["Detail"].exists)
        XCTAssertTrue(picker.buttons["Evolution"].exists)
    }

    // MARK: - Evolution Content

    /// Verifies that a mole with multiple scans shows the dual carousel and metric picker in Evolution.
    func testSelectingMoleWithMultipleScansShowsDualCarouselAndMetricPicker() {
        Helpers.openMoleDetail(person: "Alex", mole: "Left Arm Mole", in: app)
        Helpers.switchToEvolution(in: app)

        let container = app.otherElements["dualCarouselContainer"]
        XCTAssertTrue(container.waitForExistence(timeout: 5),
                       "Dual carousel should appear for a mole with multiple scans in Evolution")
        XCTAssertTrue(app.segmentedControls["metricPicker"].exists,
                       "Metric picker should appear when a mole has multiple scans")
    }

    /// Verifies that a mole with only one scan shows the single carousel without a metric picker.
    func testSelectingMoleWithSingleScanShowsSingleCarousel() {
        Helpers.openMoleDetail(person: "Alex", mole: "Back Mole", in: app)
        Helpers.switchToEvolution(in: app)

        XCTAssertTrue(app.otherElements["singleCarousel"].waitForExistence(timeout: 5),
                        "Single-scan mole should show the single carousel")

        let dualContainer = app.otherElements["dualCarouselContainer"].firstMatch
        XCTAssertFalse(dualContainer.exists,
                        "Single-scan mole should not show dual carousel")

        let metricPicker = app.segmentedControls["metricPicker"]
        XCTAssertFalse(metricPicker.exists,
                        "Single-scan mole should not show metric picker")
    }

    // MARK: - Mole Dropdown In Title

    /// Verifies the title dropdown in the detail view lists other moles belonging to the same person.
    func testDetailTitleDropdownShowsOtherMolesForPerson() {
        Helpers.openMoleDetail(person: "Alex", mole: "Left Arm Mole", in: app)

        let titleMenu = app.buttons["moleDetailMolePicker"]
        XCTAssertTrue(titleMenu.waitForExistence(timeout: 3),
                      "Detail title should be a mole picker dropdown")

        titleMenu.tap()
        XCTAssertTrue(app.buttons["Back Mole"].waitForExistence(timeout: 3))
    }

    /// Verifies that switching mole from the title dropdown keeps the user inside the detail flow.
    func testSwitchingMoleFromTitleKeepsUserInsideDetailFlow() {
        Helpers.openMoleDetail(person: "Alex", mole: "Left Arm Mole", in: app)
        Helpers.switchToEvolution(in: app)

        Helpers.chooseMoleFromDetailTitle("Back Mole", in: app)

        XCTAssertTrue(app.segmentedControls["moleDetailPagePicker"].waitForExistence(timeout: 3),
                      "Switching mole from title should not pop back to overview")
        XCTAssertTrue(app.otherElements["singleCarousel"].waitForExistence(timeout: 5),
                      "Evolution page should remain visible for the newly selected mole")
    }

    /// Verifies the switched mole remains selected after switching tabs and returning.
    func testSwitchedMolePersistsAcrossTabSwitchesWhileDetailIsOpen() {
        Helpers.openMoleDetail(person: "Alex", mole: "Left Arm Mole", in: app)
        Helpers.chooseMoleFromDetailTitle("Back Mole", in: app)

        XCTAssertTrue(
            app.staticTexts["Diameter: 3.6 mm"].firstMatch.waitForExistence(timeout: 5)
            || app.staticTexts["Diameter: 3,6 mm"].firstMatch.waitForExistence(timeout: 5),
            "Back Mole should be visible before switching tabs"
        )

        Helpers.switchToEvolution(in: app)
        Helpers.openReminderTab(in: app)
        Helpers.openOverviewTabWhenDetailOrEvolutionIsOpen(in: app)

        XCTAssertTrue(app.segmentedControls["moleDetailPagePicker"].waitForExistence(timeout: 3),
                      "Detail flow should still be open after tab switches")
        XCTAssertTrue(
            app.staticTexts["Diameter: 3.6 mm"].firstMatch.waitForExistence(timeout: 5)
            || app.staticTexts["Diameter: 3,6 mm"].firstMatch.waitForExistence(timeout: 5),
            "Back Mole should remain selected after tab switches"
        )
    }

    // MARK: - Mock Container Data Verification
    //
    // The following tests assert that every value seeded by `MockData.insertSampleData`
    // is surfaced correctly in MoleDetailView. The mock data contains:
    //   • Person "Alex"   → Mole "Left Arm Mole" (Left Arm) with 3 scans
    //                                  diameters 4.2 / 4.8 / 5.0 mm
    //                                  areas     13.8 / 15.4 / 16.0 mm²
    //                       Mole "Back Mole"     (Back) with 1 scan
    //                                  diameter  3.6 mm, area 10.1 mm²
    //   • Person "Jordan" → Mole "Face Mole"     (Face) with 1 scan
    //                                  diameter  2.9 mm, area 6.6 mm²
    //
    // For the multi-scan mole, the carousel is sorted descending by capture date,
    // so the first frame corresponds to the latest scan
    // (5 days ago: diameter 4.8 mm, area 15.4 mm²).

    /// Verifies the overview contains all mocked people from the seeded data.
    func testOverviewContainsAllMockedPeople() {
        Helpers.openOverviewTab(in: app)
        XCTAssertTrue(app.staticTexts["Alex"].waitForExistence(timeout: 3),
                       "Overview should contain Alex from mock data")

        Helpers.movePersonSelection(to: "Jordan", in: app)
        XCTAssertTrue(app.staticTexts["Jordan"].waitForExistence(timeout: 3),
                      "Overview navigation should reach Jordan from mock data")
        
        Helpers.movePersonSelection(to: "Taylor", in: app)
        XCTAssertTrue(app.staticTexts["Taylor"].waitForExistence(timeout: 3),
                      "Overview navigation should reach Taylor from mock data")
    }

    /// Verifies Alex's detail title menu lists all mocked moles.
    func testDetailTitleMenuContainsAllMockedMolesForAlex() {
        Helpers.openMoleDetail(person: "Alex", mole: "Left Arm Mole", in: app)

        let titleMenu = app.buttons["moleDetailMolePicker"]
        titleMenu.tap()

        XCTAssertTrue(app.buttons["Left Arm Mole"].waitForExistence(timeout: 3),
                       "Detail title menu should contain Left Arm Mole")
        XCTAssertTrue(app.buttons["Back Mole"].exists,
                       "Detail title menu should contain Back Mole")
    }

    /// Verifies Jordan's detail title menu lists all mocked moles.
    func testDetailTitleMenuContainsAllMockedMolesForJordan() {
        Helpers.openMoleDetail(person: "Jordan", mole: "Face Mole", in: app)

        let titleMenu = app.buttons["moleDetailMolePicker"]
        titleMenu.tap()

        XCTAssertTrue(app.buttons["Face Mole"].waitForExistence(timeout: 3),
                       "Jordan's detail title menu should contain Face Mole")
    }

    /// Verifies the carousel shows the correct diameter and area for the first scan of Left Arm Mole.
    func testLeftArmMoleShowsFirstScanDiameterAndArea() {
        // With latest-first ordering, the first scan for Left Arm Mole is alexScan4
        // (6 days ago) with diameter 5.0 mm and area 16.0 mm².
        Helpers.openMoleDetail(person: "Alex", mole: "Left Arm Mole", in: app)

        XCTAssertTrue(
            app.staticTexts["Diameter: 5.0 mm"].firstMatch.waitForExistence(timeout: 3)
            || app.staticTexts["Diameter: 5,0 mm"].firstMatch.waitForExistence(timeout: 3),
            "Carousel should display diameter 5.0/5,0 mm for the latest Left Arm scan"
        )
        XCTAssertTrue(
            app.staticTexts["Area: 16.0 mm²"].firstMatch.exists
            || app.staticTexts["Area: 16,0 mm²"].firstMatch.exists,
            "Carousel should display area 16.0/16,0 mm² for the latest Left Arm scan"
        )
    }

    /// Verifies the carousel shows the correct diameter and area for Back Mole.
    func testBackMoleShowsCorrectDiameterAndArea() {
        // Back Mole has a single scan with diameter 3.6 mm and area 10.1 mm².
        Helpers.openMoleDetail(person: "Alex", mole: "Back Mole", in: app)

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

    /// Verifies the carousel shows the correct diameter and area for Jordan's Face Mole.
    func testFaceMoleShowsCorrectDiameterAndAreaForJordan() {
        // Face Mole has a single scan with diameter 2.9 mm and area 6.6 mm².
        Helpers.openMoleDetail(person: "Jordan", mole: "Face Mole", in: app)

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

    /// Verifies the area trend evolution value matches the mock data for Left Arm Mole.
    func testLeftArmMoleAreaTrendEvolutionMatchesMockData() {
        // Areas sorted by date: 15.4 → 13.8 → 16.0 → evolution = 16.0 - 15.4 = +0.6 mm²
        Helpers.openMoleDetail(person: "Alex", mole: "Left Arm Mole", in: app)
        Helpers.switchToEvolution(in: app)

        XCTAssertTrue(app.staticTexts["Area Trend"].waitForExistence(timeout: 5),
                       "Chart should default to Area Trend")
        XCTAssertTrue(
            app.staticTexts["+0.6 mm²"].exists || app.staticTexts["+0,6 mm²"].exists,
            "Area Trend evolution should be +0.6/+0,6 mm² for the seeded Left Arm scans"
        )
    }

    /// Verifies the diameter trend evolution value matches the mock data for Left Arm Mole.
    func testLeftArmMoleDiameterTrendEvolutionMatchesMockData() {
        // Diameters sorted by date: 4.8 → 4.2 → 5.0 → evolution = 5 - 4.8 = +0.2 mm
        Helpers.openMoleDetail(person: "Alex", mole: "Left Arm Mole", in: app)
        Helpers.switchToEvolution(in: app)

        let picker = app.segmentedControls["metricPicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.buttons["Diameter"].tap()

        XCTAssertTrue(app.staticTexts["Diameter Trend"].waitForExistence(timeout: 3),
                       "Chart should switch to Diameter Trend")
        XCTAssertTrue(
            app.staticTexts["+0.2 mm"].exists || app.staticTexts["+0,2 mm"].exists,
            "Diameter Trend evolution should be +0.2/+0,2 mm for the seeded Left Arm scans"
        )
    }

    // Note: per-point chart annotations are not reliably queryable from XCUI
    // because Swift Charts hosts annotation views inside an opaque backing
    // element. Per-point data flow is instead verified by the unit tests in
    // `Tests/PipelineTests/ChartViewDataTests.swift`, which exercise
    // `ChartView.makeChartData(for:metric:)` directly.
}
