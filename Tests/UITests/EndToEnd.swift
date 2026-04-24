// 
// EndToEnd.swift
// P8-ProductUITests
//

import XCTest
import UIKit

final class EndToEnd: XCTestCase {

    // Launches directly into the Capture tab with mocked segmentation data
    private var app: XCUIApplication!
    private let defaultLaunchArguments = 
        ["-SkipModelLoading", 
        "-UITest_InMemoryStore", 
        "-UITest_InjectCapturedImage",
        "-UITest_MockSegmentationResult",
        ]
   
    override func setUpWithError() throws {
    continueAfterFailure = false
    app = XCUIApplication()
    
    // Define arguments in the correct Key-Value sequence
    app.launchArguments = [
        "-SkipModelLoading", 
        "-UITest_InMemoryStore", 
        "-UITest_MockSegmentationResult",
        "-UITest_InjectCapturedImage", 
        Self.onePixelPNGBase64() // This must follow the key!
    ]
    
    app.launch()
    Helpers.openCaptureTab(in: app)
}

    func testCapturedImageCanCreateNewMoleFromSegmentationFlow() {

        let useMockDetectionButton = app.buttons["segmentationUseMockDetectionButton"].firstMatch
        XCTAssertTrue(useMockDetectionButton.waitForExistence(timeout: 5), "Expected mocked detection button to appear in mocked segmentation flow")
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

    func testCapturedImageCanAddScanToExistingMoleFromSegmentationFlow() {

        let useMockDetectionButton = app.buttons["segmentationUseMockDetectionButton"].firstMatch
        XCTAssertTrue(useMockDetectionButton.waitForExistence(timeout: 5), "Expected mocked detection button to appear in mocked segmentation flow")
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

    // MARK: - Helpers
      private static func onePixelPNGBase64() -> String {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
        let image = renderer.image { ctx in
            UIColor.gray.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        return image.pngData()!.base64EncodedString()
    }

}
