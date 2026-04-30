//
//  P8_ProductUITestsLaunchTests.swift
//  P8-ProductUITests
//
//  Created by Simon Thordal on 31/03/2026.
//

import XCTest

/// UI tests that verify the app launches without crashing and captures a launch screenshot.
final class ProductUITestsLaunchTests: XCTestCase {

    override static var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Verifies the app launches successfully and attaches a launch screen screenshot.
    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
