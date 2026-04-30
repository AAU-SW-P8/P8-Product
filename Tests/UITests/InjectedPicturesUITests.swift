//
// EndToEnd.swift
// P8-ProductUITests
//

import UIKit
import XCTest

/// UI tests for the injected-image segmentation flow, covering new-mole creation, existing-mole scan addition, cancellation, and persistence.
final class InjectedPicturesUITests: XCTestCase {

  /// The application instance under test.
  private var app: XCUIApplication!

  override func setUpWithError() throws {
    continueAfterFailure = false
    app = XCUIApplication()

    // Define arguments in the correct Key-Value sequence
    app.launchArguments = [
      "-SkipModelLoading",
      "-UITest_InMemoryStore",
      "-UITest_MockSegmentationResult",
      "-UITest_InjectCapturedImage",
      Self.onePixelPNGBase64(),  // This must follow the key!
    ]

    app.launch()
    Helpers.openCaptureTab(in: app)
  }

  // MARK: - Segmentation Flow Tests
  /// Verifies a captured image can be used to create a new mole through the segmentation flow.
  func testCapturedImageCanCreateNewMoleFromSegmentationFlow() {

    let useMockDetectionButton = app.buttons["segmentationUseMockDetectionButton"].firstMatch
    XCTAssertTrue(
      useMockDetectionButton.waitForExistence(timeout: 5),
      "Expected mocked detection button to appear in mocked segmentation flow")
    useMockDetectionButton.tap()

    let newMoleButton = app.buttons["segmentationChooseNewMoleButton"].firstMatch
    XCTAssertTrue(newMoleButton.waitForExistence(timeout: 3), "Expected new mole button to appear")
    newMoleButton.tap()

    let nameField = app.textFields["segmentationNewMoleNameField"].firstMatch
    XCTAssertTrue(nameField.waitForExistence(timeout: 3), "Expected name field to appear")
    nameField.tap()
    nameField.typeText("UI Test Mole")

    let saveButton = app.buttons["segmentationNewMoleSaveButton"].firstMatch
    XCTAssertTrue(saveButton.waitForExistence(timeout: 3), "Expected save button to appear")
    saveButton.tap()

    Helpers.openOverviewTab(in: app)
    XCTAssertTrue(
      app.staticTexts["UI Test Mole"].waitForExistence(timeout: 5),
      "New mole created from segmentation should appear in Overview"
    )
  }

  /// Verifies a captured image can be added as a new scan to an existing mole.
  func testCapturedImageCanAddScanToExistingMoleFromSegmentationFlow() {

    let useMockDetectionButton = app.buttons["segmentationUseMockDetectionButton"].firstMatch
    XCTAssertTrue(
      useMockDetectionButton.waitForExistence(timeout: 5),
      "Expected mocked detection button to appear in mocked segmentation flow")
    useMockDetectionButton.tap()

    let existingButton = app.buttons["segmentationChooseExistingMoleButton"].firstMatch
    XCTAssertTrue(existingButton.waitForExistence(timeout: 3))
    existingButton.tap()

    let existingMoleRow = app.buttons["segmentationExistingMoleRow_Back Mole"].firstMatch
    XCTAssertTrue(existingMoleRow.waitForExistence(timeout: 3))
    existingMoleRow.tap()

    Helpers.openOverviewTab(in: app)
    Helpers.openMoleDetail(person: "Alex", mole: "Back Mole", in: app)
    Helpers.switchToEvolution(in: app)

    XCTAssertTrue(
      app.otherElements["dualCarouselContainer"].waitForExistence(timeout: 5),
      "Back Mole should show dual carousel after adding a second scan from segmentation"
    )
    XCTAssertTrue(
      app.segmentedControls["metricPicker"].waitForExistence(timeout: 3),
      "Back Mole should show metric picker after gaining multiple scans"
    )
  }

  /// Verifies canceling the existing-mole selection returns to the segmentation view without changes.
  func testCapturedImageAddedToExistingMoleCanCancelAndNotAppearInOverview() {

    let useMockDetectionButton = app.buttons["segmentationUseMockDetectionButton"].firstMatch
    XCTAssertTrue(
      useMockDetectionButton.waitForExistence(timeout: 5),
      "Expected mocked detection button to appear in mocked segmentation flow")
    useMockDetectionButton.tap()

    let existingButton = app.buttons["segmentationChooseExistingMoleButton"].firstMatch
    XCTAssertTrue(existingButton.waitForExistence(timeout: 3))
    existingButton.tap()

    let cancelButton = app.buttons["segmentationSelectMoleCancelButton"].firstMatch
    XCTAssertTrue(cancelButton.waitForExistence(timeout: 3))
    cancelButton.tap()

    XCTAssertTrue(
      useMockDetectionButton.waitForExistence(timeout: 3),
      "Should return to mocked segmentation view after cancelling existing mole selection")

  }

  /// Verifies canceling new-mole creation returns to the segmentation view and does not add the mole to the overview.
  func testCapturedImageCreateNewMoleCanCancelAndNotAppearInOverview() {

    let useMockDetectionButton = app.buttons["segmentationUseMockDetectionButton"].firstMatch
    XCTAssertTrue(
      useMockDetectionButton.waitForExistence(timeout: 5),
      "Expected mocked detection button to appear in mocked segmentation flow")
    useMockDetectionButton.tap()

    let newMoleButton = app.buttons["segmentationChooseNewMoleButton"].firstMatch
    XCTAssertTrue(newMoleButton.waitForExistence(timeout: 3), "Expected new mole button to appear")
    newMoleButton.tap()

    let nameField = app.textFields["segmentationNewMoleNameField"].firstMatch
    XCTAssertTrue(nameField.waitForExistence(timeout: 3), "Expected name field to appear")
    nameField.tap()
    nameField.typeText("UI Test Mole")

    let cancelButton = app.buttons["segmentationNewMoleCancelButton"].firstMatch
    XCTAssertTrue(cancelButton.waitForExistence(timeout: 3))
    cancelButton.tap()

    XCTAssertTrue(
      useMockDetectionButton.waitForExistence(timeout: 3),
      "Should return to mocked segmentation view after cancelling new mole creation")

    Helpers.openOverviewTab(in: app)
    XCTAssertFalse(
      app.staticTexts["UI Test Mole"].waitForExistence(timeout: 5),
      "New mole that was cancelled should not appear in Overview"
    )
  }

  // MARK: - Persistence Tests
  /// Verifies a newly created mole persists in the overview after the app is relaunched.
  func testCapturedImageCanCreateNewMolePersistAfterAppRelaunch() {
    app.terminate()
    launchApp(arguments: [
      "-UITest_PersistentStore", "-SkipModelLoading", "-UITest_InjectCapturedImage",
      Self.onePixelPNGBase64(), "-UITest_MockSegmentationResult",
    ])
    Helpers.openCaptureTab(in: app)
    let useMockDetectionButton = app.buttons["segmentationUseMockDetectionButton"].firstMatch
    XCTAssertTrue(
      useMockDetectionButton.waitForExistence(timeout: 5),
      "Expected mocked detection button to appear in mocked segmentation flow")
    useMockDetectionButton.tap()

    let newMoleButton = app.buttons["segmentationChooseNewMoleButton"].firstMatch
    XCTAssertTrue(newMoleButton.waitForExistence(timeout: 3), "Expected new mole button to appear")
    newMoleButton.tap()

    let nameField = app.textFields["segmentationNewMoleNameField"].firstMatch
    XCTAssertTrue(nameField.waitForExistence(timeout: 3), "Expected name field to appear")
    nameField.tap()
    nameField.typeText("Persistent Mole")

    let saveButton = app.buttons["segmentationNewMoleSaveButton"].firstMatch
    XCTAssertTrue(saveButton.waitForExistence(timeout: 3), "Expected save button to appear")
    saveButton.tap()

    // Relaunch the app to verify persistence
    app.terminate()
    launchApp(arguments: ["-UITest_PersistentStore", "-SkipModelLoading"])

    Helpers.openOverviewTab(in: app)
    XCTAssertTrue(
      app.staticTexts["Persistent Mole"].waitForExistence(timeout: 5),
      "New mole created from segmentation should persist and appear in Overview after app relaunch"
    )
  }

  /// Verifies an added scan persists in the mole detail view after the app is relaunched.
  func testCapturedImageCanAddScanToExistingMolePersistAfterAppRelaunch() {
    app.terminate()
    launchApp(arguments: [
      "-UITest_PersistentStore", "-SkipModelLoading", "-UITest_MockSegmentationResult",
      "-UITest_InjectCapturedImage", Self.onePixelPNGBase64(),
    ])
    Helpers.openCaptureTab(in: app)
    let useMockDetectionButton = app.buttons["segmentationUseMockDetectionButton"].firstMatch
    XCTAssertTrue(
      useMockDetectionButton.waitForExistence(timeout: 5),
      "Expected mocked detection button to appear in mocked segmentation flow")
    useMockDetectionButton.tap()

    let existingButton = app.buttons["segmentationChooseExistingMoleButton"].firstMatch
    XCTAssertTrue(existingButton.waitForExistence(timeout: 5))
    existingButton.tap()

    let existingMoleRow = app.buttons["segmentationExistingMoleRow_Back Mole"].firstMatch
    XCTAssertTrue(existingMoleRow.waitForExistence(timeout: 3))
    existingMoleRow.tap()

    // Relaunch the app to verify persistence
    app.terminate()
    launchApp(arguments: ["-UITest_PersistentStore", "-SkipModelLoading"])

    Helpers.openOverviewTab(in: app)
    Helpers.openMoleDetail(person: "Alex", mole: "Back Mole", in: app)
    Helpers.switchToEvolution(in: app)

    XCTAssertTrue(
      app.otherElements["dualCarouselContainer"].waitForExistence(timeout: 5),
      "Back Mole should still show dual carousel after app relaunch"
    )
    XCTAssertTrue(
      app.segmentedControls["metricPicker"].waitForExistence(timeout: 3),
      "Back Mole should still show metric picker after app relaunch"
    )
  }

  // MARK: - Helpers
  /// Builds a 1×1 solid-gray PNG and returns it base64-encoded for use as a launch argument.
  private static func onePixelPNGBase64() -> String {
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
    let image = renderer.image { ctx in
      UIColor.gray.setFill()
      ctx.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
    }
    return image.pngData()!.base64EncodedString()
  }

  /// Terminates the app, applies the given launch arguments, and relaunches.
  private func launchApp(arguments: [String]) {
    app.terminate()
    app.launchArguments = arguments
    app.launch()
  }
}
