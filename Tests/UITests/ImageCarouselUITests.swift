//
//  ImageCarouselUITests.swift
//  P8-ProductUITests
//
//  Tests for the ImageCarousel view, covering the visible measurement labels
//  and swipe navigation between scans. The tests reach the carousel through
//  MoleDetailView's Evolution page because its dual-carousel layout exposes
//  stable accessibility identifiers for each carousel.
//
//  Mock data assumed (see MockData.insertSampleData):
//    Alex / "Left Arm Mole" — 3 scans shown newest-first in the detail page:
//      1. alexScan4 ( 6 days ago) — diameter 5.0 mm, area 16.0 mm²
//      2. alexScan2 (20 days ago) — diameter 4.8 mm, area 15.4 mm²
//      3. alexScan1 (60 days ago) — diameter 4.2 mm, area 13.8 mm²
//    Alex / "Back Mole" — 1 scan, diameter 3.6 mm, area 10.1 mm².
//

import XCTest

/// UI tests for the ImageCarousel view, verifying measurement labels and swipe navigation.
final class ImageCarouselUITests: XCTestCase {

    /// The application instance under test.
    private var app: XCUIApplication!

    /// Asserts that the given carousel element displays the expected diameter and optional area labels.
    private func assertCarousel(
        _ carousel: XCUIElement,
        showsDiameter diameter: String,
        area: String? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let decimalVariants = [diameter, diameter.replacingOccurrences(of: ".", with: ",")]
        let diameterMatches = decimalVariants.contains { carousel.staticTexts["Diameter: \($0) mm"].exists }

        XCTAssertTrue(
            diameterMatches,
            "Expected carousel to show diameter \(diameter)",
            file: file,
            line: line
        )

        if let area {
            let areaVariants = [area, area.replacingOccurrences(of: ".", with: ",")]
            let areaMatches = areaVariants.contains { carousel.staticTexts["Area: \($0) mm²"].exists }

            XCTAssertTrue(
                areaMatches,
                "Expected carousel to show area \(area)",
                file: file,
                line: line
            )
        }
    }

    /// Returns the first candidate diameter string that is currently shown in the given carousel element.
    private func observedDiameter(
        in carousel: XCUIElement,
        candidates: [String]
    ) -> String? {
        candidates.first { candidate in
            carousel.staticTexts["Diameter: \(candidate) mm"].exists
        }
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("-SkipModelLoading")
        app.launchArguments.append("-UITest_InMemoryStore")
        app.launch()

        Helpers.openOverviewTab(in: app)
    }

    // MARK: - Image Loading

    /// Verifies the carousel displays the correct scan data when the detail view is first opened.
    func testCarouselShowsSelectedScanOnLoad() {
        Helpers.openMoleDetail(person: "Alex", mole: "Left Arm Mole", in: app)
        Helpers.switchToEvolution(in: app)

        let leftCarousel = app.otherElements["leftCarousel"]
        XCTAssertTrue(leftCarousel.waitForExistence(timeout: 5))
        assertCarousel(leftCarousel, showsDiameter: "4.8", area: "15.4")
    }

    // MARK: - Swipe Navigation
    /// Verifies that swiping through the carousel reveals each scan in sequence.
    func testSwipingThroughAllScansShowsEachOne() {
        // Left carousel starts at last index, so order while swiping left is:
        // 4.8 mm → 4.2 mm → 5.0 mm.
        Helpers.openMoleDetail(person: "Alex", mole: "Left Arm Mole", in: app)
        Helpers.switchToEvolution(in: app)

        let leftCarousel = app.otherElements["leftCarousel"]
        XCTAssertTrue(leftCarousel.waitForExistence(timeout: 5))
        XCTAssertTrue(
            leftCarousel.staticTexts["Diameter: 4.8 mm"].waitForExistence(timeout: 3)
            || leftCarousel.staticTexts["Diameter: 4,8 mm"].waitForExistence(timeout: 3)
        )

        leftCarousel.swipeLeft()
        XCTAssertTrue(
            leftCarousel.staticTexts["Diameter: 4.2 mm"].waitForExistence(timeout: 3)
            || leftCarousel.staticTexts["Diameter: 4,2 mm"].waitForExistence(timeout: 3),
            "Second swipe target should be the 4.2 mm scan"
        )

        leftCarousel.swipeLeft()
        XCTAssertTrue(
            leftCarousel.staticTexts["Diameter: 5.0 mm"].waitForExistence(timeout: 3)
            || leftCarousel.staticTexts["Diameter: 5,0 mm"].waitForExistence(timeout: 3),
            "Third swipe target should be the 5.0 mm scan"
        )
        XCTAssertTrue(
            leftCarousel.staticTexts["Area: 16.0 mm²"].exists
            || leftCarousel.staticTexts["Area: 16,0 mm²"].exists,
            "Third scan area should be 16.0 mm²"
        )
    }

    /// Verifies the left and right carousels track their selected scan independently.
    func testLeftAndRightCarouselsTrackSelectionIndependently() {
        Helpers.openMoleDetail(person: "Alex", mole: "Left Arm Mole", in: app)
        Helpers.switchToEvolution(in: app)

        let leftCarousel = app.otherElements["leftCarousel"]
        let rightCarousel = app.otherElements["rightCarousel"]
        XCTAssertTrue(leftCarousel.waitForExistence(timeout: 5))
        XCTAssertTrue(rightCarousel.waitForExistence(timeout: 5))
        assertCarousel(leftCarousel, showsDiameter: "4.8", area: "15.4")
        assertCarousel(rightCarousel, showsDiameter: "5.0", area: "16.0")

        let initialRightDiameter = observedDiameter(in: rightCarousel, candidates: ["5.0", "5,0"])
        XCTAssertNotNil(initialRightDiameter)

        leftCarousel.swipeLeft()

        let movedLeftDiameter = observedDiameter(in: leftCarousel, candidates: ["4.2", "4,2", "4.8", "4,8"])
        XCTAssertNotNil(movedLeftDiameter)
        XCTAssertNotEqual(movedLeftDiameter, "5.0")
        XCTAssertNotEqual(movedLeftDiameter, "5,0")
        XCTAssertTrue(
            movedLeftDiameter == "4.2" || movedLeftDiameter == "4,2",
            "After swipe, left carousel should show 4.2 mm scan"
        )
        let currentRightDiameter = observedDiameter(in: rightCarousel, candidates: ["5.0", "5,0"])
        XCTAssertEqual(currentRightDiameter, initialRightDiameter)
    }

    // MARK: - Delete Scan Flow

    /// Verifies the detail carousel shows a delete button for the selected scan.
    func testDetailCarouselShowsDeleteButton() {
        Helpers.openMoleDetail(person: "Alex", mole: "Left Arm Mole", in: app)

        let deleteButton = app.buttons["deleteMoleScanButton"]
        XCTAssertTrue(
            deleteButton.waitForExistence(timeout: 3),
            "Detail carousel should show delete button for selected scan"
        )
    }

    /// Verifies that canceling the delete scan alert leaves the current scan unchanged.
    func testCancelDeleteScanKeepsCurrentScan() {
        Helpers.openMoleDetail(person: "Alex", mole: "Left Arm Mole", in: app)

        XCTAssertTrue(
            app.staticTexts["Diameter: 5.0 mm"].firstMatch.waitForExistence(timeout: 3)
            || app.staticTexts["Diameter: 5,0 mm"].firstMatch.waitForExistence(timeout: 3),
            "Canceling delete should keep currently selected scan"
        )
        let deleteButton = app.buttons["deleteMoleScanButton"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 3))
        deleteButton.tap()

        let alert = app.alerts["Delete Scan"]
        XCTAssertTrue(alert.waitForExistence(timeout: 3))
        alert.buttons["Cancel"].tap()

        XCTAssertTrue(
            app.staticTexts["Diameter: 5.0 mm"].firstMatch.waitForExistence(timeout: 3)
            || app.staticTexts["Diameter: 5,0 mm"].firstMatch.waitForExistence(timeout: 3),
            "Canceling delete should keep currently selected scan"
        )
    }

    /// Verifies that confirming a scan deletion removes it and advances the carousel to the next scan.
    func testConfirmDeleteScanRemovesSelectedInstanceAndShowsNextScan() {
        Helpers.openMoleDetail(person: "Alex", mole: "Left Arm Mole", in: app)

        XCTAssertTrue(
            app.staticTexts["Diameter: 5.0 mm"].firstMatch.waitForExistence(timeout: 3)
            || app.staticTexts["Diameter: 5,0 mm"].firstMatch.waitForExistence(timeout: 3),
            "Deleting the latest Left Arm scan should move detail view to the next available scan"
        )

        let deleteButton = app.buttons["deleteMoleScanButton"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 3))
        deleteButton.tap()

        let alert = app.alerts["Delete Scan"]
        XCTAssertTrue(alert.waitForExistence(timeout: 3))
        alert.buttons["Delete"].tap()

        XCTAssertTrue(
            app.staticTexts["Diameter: 4.2 mm"].firstMatch.waitForExistence(timeout: 3)
            || app.staticTexts["Diameter: 4,2 mm"].firstMatch.waitForExistence(timeout: 3),
            "Deleting the latest Left Arm scan should move detail view to the next available scan"
        )
        XCTAssertFalse(app.alerts["Delete Scan"].exists)
    }

    /// Verifies that deleting the only scan of a mole also deletes the mole and returns to the overview.
    func testDeletingLastScanDeletesMoleAndReturnsToOverview() {
        Helpers.openMoleDetail(person: "Alex", mole: "Back Mole", in: app)

        let deleteButton = app.buttons["deleteMoleScanButton"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 3))
        deleteButton.tap()

        let alert = app.alerts["Delete Scan"]
        XCTAssertTrue(alert.waitForExistence(timeout: 3))
        alert.buttons["Delete"].tap()

        XCTAssertTrue(
            app.staticTexts["Mole Overview"].waitForExistence(timeout: 3),
            "Deleting the last scan should dismiss detail and return to overview"
        )
        XCTAssertFalse(
            app.segmentedControls["moleDetailPagePicker"].exists,
            "Detail page picker should no longer be visible after dismissal"
        )
        XCTAssertFalse(
            app.staticTexts["Back Mole"].exists,
            "Mole with no scans should be deleted and no longer shown in overview"
        )
        XCTAssertTrue(app.staticTexts["Left Arm Mole"].exists)
    }
}
