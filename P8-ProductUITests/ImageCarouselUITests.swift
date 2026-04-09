//
//  ImageCarouselUITests.swift
//  P8-ProductUITests
//
//  Tests for the ImageCarousel view, covering image loading
//  and swipe navigation between scans. The tests reach the
//  carousel through CompareView since its dual-carousel layout
//  exposes stable accessibility identifiers for each carousel.
//
//  Mock data assumed (see MockData.insertSampleData):
//    Alex / "Left Arm Mole" — 3 scans, sorted ascending by capture date:
//      1. alexScan4 (60 days ago) — diameter 5.0 mm, area 16.0 mm²
//      2. alexScan1 (20 days ago) — diameter 4.2 mm, area 13.8 mm²
//      3. alexScan2 ( 5 days ago) — diameter 4.8 mm, area 15.4 mm²
//    Alex / "Back Mole" — 1 scan, diameter 3.6 mm, area 10.1 mm².
//

import XCTest

final class ImageCarouselUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()

        // The dual carousel lives in the Compare tab.
        app.tabBars.buttons["Compare"].tap()
    }

    // MARK: - Helpers

    private var personPickerButton: XCUIElement {
        app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Person")
        ).firstMatch
    }

    private var molePickerButton: XCUIElement {
        app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Select Mole")
        ).firstMatch
    }

    /// Selects Alex's "Left Arm Mole" — the only mock mole with multiple
    /// scans, so the only one that surfaces the dual carousel.
    private func selectAlexLeftArmMole() {
        personPickerButton.tap()
        app.buttons["Alex"].tap()

        molePickerButton.tap()
        app.buttons["Left Arm Mole"].tap()

        XCTAssertTrue(
            app.otherElements["dualCarouselContainer"].waitForExistence(timeout: 5),
            "Dual carousel container should appear after selecting Left Arm Mole"
        )
    }

    /// Selects Alex's single-scan "Back Mole".
    private func selectAlexBackMole() {
        personPickerButton.tap()
        app.buttons["Alex"].tap()

        molePickerButton.tap()
        app.buttons["Back Mole"].tap()
    }

    // MARK: - Image Loading

    func testCarouselLoadsImageForFirstScan() {
        selectAlexLeftArmMole()

        let topCarousel = app.otherElements["topCarousel"]
        XCTAssertTrue(topCarousel.waitForExistence(timeout: 5))

        // Each rendered scan produces an SwiftUI Image element. The LazyHStack
        // only materialises the visible page, so we just need at least one.
        XCTAssertGreaterThan(
            topCarousel.images.count, 0,
            "Top carousel should render an image element for the visible scan"
        )
    }

    func testSingleScanCarouselLoadsImage() {
        // Back Mole renders through the single-carousel branch in CompareView,
        // which doesn't tag the carousel with topCarousel/bottomCarousel ids,
        // so we look at the metadata instead and assert at least one image
        // exists in the application's element tree.
        selectAlexBackMole()

        XCTAssertTrue(
            app.staticTexts["Diameter: 3.6 mm"].firstMatch.waitForExistence(timeout: 5),
            "Single-scan carousel should display Back Mole's diameter"
        )
        XCTAssertGreaterThan(
            app.images.count, 0,
            "Single-scan carousel should render an image element for the loaded scan"
        )
    }

    // MARK: - Swipe Navigation

    func testSwipingTopCarouselBackwardReturnsToPreviousScan() {
        // Swipe forward then back; the carousel should return to the first scan.
        selectAlexLeftArmMole()

        let topCarousel = app.otherElements["topCarousel"]
        XCTAssertTrue(topCarousel.waitForExistence(timeout: 5))

        topCarousel.swipeLeft()
        XCTAssertTrue(topCarousel.staticTexts["Diameter: 4.2 mm"].waitForExistence(timeout: 3))

        topCarousel.swipeRight()

        XCTAssertTrue(
            topCarousel.staticTexts["Diameter: 5.0 mm"].waitForExistence(timeout: 3),
            "Swiping right should return the top carousel to the first scan (5.0 mm)"
        )
    }

    func testSwipingThroughAllScansShowsEachOne() {
        // Walk through all 3 scans of Left Arm Mole in order:
        // 5.0 mm → 4.2 mm → 4.8 mm.
        selectAlexLeftArmMole()

        let topCarousel = app.otherElements["topCarousel"]
        XCTAssertTrue(topCarousel.waitForExistence(timeout: 5))
        XCTAssertTrue(topCarousel.staticTexts["Diameter: 5.0 mm"].waitForExistence(timeout: 3))

        topCarousel.swipeLeft()
        XCTAssertTrue(
            topCarousel.staticTexts["Diameter: 4.2 mm"].waitForExistence(timeout: 3),
            "Second swipe target should be the 4.2 mm scan"
        )

        topCarousel.swipeLeft()
        XCTAssertTrue(
            topCarousel.staticTexts["Diameter: 4.8 mm"].waitForExistence(timeout: 3),
            "Third swipe target should be the 4.8 mm scan"
        )
        XCTAssertTrue(
            topCarousel.staticTexts["Area: 15.4 mm²"].exists,
            "Third scan area should be 15.4 mm²"
        )
    }

    func testTopAndBottomCarouselsSwipeIndependently() {
        // The two carousels share data but maintain separate selectedIndex
        // bindings, so swiping the top must not affect the bottom.
        selectAlexLeftArmMole()

        let topCarousel = app.otherElements["topCarousel"]
        let bottomCarousel = app.otherElements["bottomCarousel"]
        XCTAssertTrue(topCarousel.waitForExistence(timeout: 5))
        XCTAssertTrue(bottomCarousel.waitForExistence(timeout: 5))

        topCarousel.swipeLeft()

        XCTAssertTrue(
            topCarousel.staticTexts["Diameter: 4.2 mm"].waitForExistence(timeout: 3),
            "Top carousel should have advanced to the second scan"
        )
        XCTAssertTrue(
            bottomCarousel.staticTexts["Diameter: 5.0 mm"].exists,
            "Bottom carousel should remain on the first scan after swiping the top"
        )
    }

}
