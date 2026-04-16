//
//  ImageCarouselUITests.swift
//  P8-ProductUITests
//
//  Tests for the ImageCarousel view, covering image loading
//  and swipe navigation between scans. The tests reach the
//  carousel through MoleDetailView's Evolution page since its dual-carousel layout
//  exposes stable accessibility identifiers for each carousel.
//
//  Mock data assumed (see MockData.insertSampleData):
//    Alex / "Left Arm Mole" — 3 scans shown latest-first in the carousel:
//      1. alexScan2 ( 5 days ago) — diameter 4.8 mm, area 15.4 mm²
//      2. alexScan1 (20 days ago) — diameter 4.2 mm, area 13.8 mm²
//      3. alexScan4 (60 days ago) — diameter 5.0 mm, area 16.0 mm²
//    Alex / "Back Mole" — 1 scan, diameter 3.6 mm, area 10.1 mm².
//

import XCTest


final class ImageCarouselUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("-SkipModelLoading")
        app.launchArguments.append("-UITest_InMemoryStore")
        app.launch()

        Helpers.openOverviewTab(in: app)
    }

    // MARK: - Image Loading

    func testCarouselLoadsImageForFirstScan() {
        Helpers.selectAlexLeftArmMole(in: app)

        let leftCarousel = app.otherElements["leftCarousel"]
        XCTAssertTrue(leftCarousel.waitForExistence(timeout: 5))

        // Each rendered scan produces an SwiftUI Image element. The LazyHStack
        // only materialises the visible page, so we just need at least one.
        XCTAssertGreaterThan(
            leftCarousel.images.count, 0,
            "Left carousel should render an image element for the visible scan"
        )
    }

    func testSingleScanCarouselLoadsImage() {
        // Back Mole renders through the single-carousel branch in MoleDetailView,
        // which doesn't tag the carousel with leftCarousel/rightCarousel ids,
        // so we look at the metadata instead and assert at least one image
        // exists in the application's element tree.
        Helpers.selectAlexBackMole(in: app)

        XCTAssertTrue(
            app.staticTexts["Diameter: 3.6 mm"].firstMatch.waitForExistence(timeout: 5)
            || app.staticTexts["Diameter: 3,6 mm"].firstMatch.waitForExistence(timeout: 5),
            "Single-scan carousel should display Back Mole's diameter with either decimal separator"
        )
        XCTAssertGreaterThan(
            app.images.count, 0,
            "Single-scan carousel should render an image element for the loaded scan"
        )
    }

    // MARK: - Swipe Navigation

    func testSwipingLeftCarouselBackwardReturnsToPreviousScan() {
        // Left carousel starts at the last index (oldest scan). Swipe toward
        // newer scans, then return to verify backward navigation.
        Helpers.selectAlexLeftArmMole(in: app)

        let leftCarousel = app.otherElements["leftCarousel"]
        XCTAssertTrue(leftCarousel.waitForExistence(timeout: 5))

        XCTAssertTrue(
            leftCarousel.staticTexts["Diameter: 5.0 mm"].waitForExistence(timeout: 3)
            || leftCarousel.staticTexts["Diameter: 5,0 mm"].waitForExistence(timeout: 3)
        )

        leftCarousel.swipeRight()
        XCTAssertTrue(
            leftCarousel.staticTexts["Diameter: 4.2 mm"].waitForExistence(timeout: 3)
            || leftCarousel.staticTexts["Diameter: 4,2 mm"].waitForExistence(timeout: 3)
        )

        leftCarousel.swipeLeft()

        XCTAssertTrue(
            leftCarousel.staticTexts["Diameter: 5.0 mm"].waitForExistence(timeout: 3)
            || leftCarousel.staticTexts["Diameter: 5,0 mm"].waitForExistence(timeout: 3),
            "Swiping left should return the left carousel to the oldest scan (5.0/5,0 mm)"
        )
    }

    func testSwipingThroughAllScansShowsEachOne() {
        // Left carousel starts at last index, so order while swiping right is:
        // 5.0 mm → 4.2 mm → 4.8 mm.
        Helpers.selectAlexLeftArmMole(in: app)

        let leftCarousel = app.otherElements["leftCarousel"]
        XCTAssertTrue(leftCarousel.waitForExistence(timeout: 5))
        XCTAssertTrue(
            leftCarousel.staticTexts["Diameter: 5.0 mm"].waitForExistence(timeout: 3)
            || leftCarousel.staticTexts["Diameter: 5,0 mm"].waitForExistence(timeout: 3)
        )

        leftCarousel.swipeRight()
        XCTAssertTrue(
            leftCarousel.staticTexts["Diameter: 4.2 mm"].waitForExistence(timeout: 3)
            || leftCarousel.staticTexts["Diameter: 4,2 mm"].waitForExistence(timeout: 3),
            "Second swipe target should be the 4.2 mm scan"
        )

        leftCarousel.swipeRight()
        XCTAssertTrue(
            leftCarousel.staticTexts["Diameter: 4.8 mm"].waitForExistence(timeout: 3)
            || leftCarousel.staticTexts["Diameter: 4,8 mm"].waitForExistence(timeout: 3),
            "Third swipe target should be the 4.8 mm scan"
        )
        XCTAssertTrue(
            leftCarousel.staticTexts["Area: 15.4 mm²"].exists
            || leftCarousel.staticTexts["Area: 15,4 mm²"].exists,
            "Third scan area should be 15.4 mm²"
        )
    }

    func testLeftAndRightCarouselsSwipeIndependently() {
        // The two carousels share data but maintain separate selectedIndex
        // bindings, so swiping the left must not affect the right.
        Helpers.selectAlexLeftArmMole(in: app)

        let leftCarousel = app.otherElements["leftCarousel"]
        let rightCarousel = app.otherElements["rightCarousel"]
        XCTAssertTrue(leftCarousel.waitForExistence(timeout: 5))
        XCTAssertTrue(rightCarousel.waitForExistence(timeout: 5))

        leftCarousel.swipeRight()

        XCTAssertTrue(
            leftCarousel.staticTexts["Diameter: 4.2 mm"].waitForExistence(timeout: 3)
            || leftCarousel.staticTexts["Diameter: 4,2 mm"].waitForExistence(timeout: 3),
            "Left carousel should have advanced to the second scan"
        )
        XCTAssertTrue(
            rightCarousel.staticTexts["Diameter: 4.8 mm"].exists
            || rightCarousel.staticTexts["Diameter: 4,8 mm"].exists,
            "Right carousel should remain on the latest scan after swiping the left"
        )
    }

}
