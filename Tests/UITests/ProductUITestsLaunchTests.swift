//
//  P8_ProductUITestsLaunchTests.swift
//  P8-ProductUITests
//

import XCTest

/// UI tests that verify the app launches without crashing and captures a launch screenshot.
final class ProductUITestsLaunchTests: XCTestCase {

  override static var runsForEachTargetApplicationUIConfiguration: Bool {
    true
  }

  /// Sets up the test environment by launching the app and navigating to the Capture tab.
  ///
  /// - Parameter error: An optional error that may have occurred during setup.
  /// - Throws: An error if the setup fails.
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
