//
//  CameraViewUITests.swift
//  P8-ProductUITests
//
//  UI tests for the Camera tab.
//
//  The iOS Simulator has no physical camera and no LiDAR, so
//  `UIImagePickerController.isSourceTypeAvailable(.camera)` is false and
//  `ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)` is false.
//  As a result `CameraView.openCamera()` is a no-op and the full-screen
//  camera cover is never presented during UI tests — the only thing the
//  simulator ever renders for this tab is the placeholder view.
//  `ARCameraView`, `ARCameraViewController`, and `BasicCameraView` all
//  require real hardware and are not covered here.
//

import XCTest
import UIKit

final class CameraViewUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-SkipModelLoading", "-UITest_InMemoryStore"]
        app.launch()

        Helpers.openCaptureTab(in: app)
    }

    // MARK: - Tab Navigation

    func testCaptureTabIsReachable() {
        let captureTab = app.tabBars.buttons["Capture"]
        XCTAssertTrue(captureTab.waitForExistence(timeout: 3),
                      "Capture tab button should exist in the tab bar")
        XCTAssertTrue(captureTab.isSelected,
                      "Capture tab should be selected after opening it")
    }

    // MARK: - Placeholder UI

    func testPlaceholderHeadlineIsVisible() {
        XCTAssertTrue(
            app.staticTexts["Opening camera..."].waitForExistence(timeout: 3),
            "Placeholder should show the 'Opening camera...' headline on simulator"
        )
    }

    func testPlaceholderSubheadlineIsVisible() {
        XCTAssertTrue(
            app.staticTexts["If camera is closed, tap anywhere to open again"]
                .waitForExistence(timeout: 3),
            "Placeholder should show the tap-to-reopen subheadline"
        )
    }

    func testPlaceholderDoesNotShowSegmentationViewByDefault() {
        // MoleSegmentationView is only pushed once an image has been captured,
        // which cannot happen on the simulator. The Capture tab should stay on
        // the placeholder indefinitely.
        XCTAssertTrue(
            app.staticTexts["Opening camera..."].waitForExistence(timeout: 3)
        )
        XCTAssertFalse(
            app.navigationBars.firstMatch.exists
                && app.navigationBars.buttons["Back"].exists,
            "No segmentation view should be pushed while there is no captured image"
        )
    }

    // MARK: - Tap-to-reopen

    func testTappingPlaceholderDoesNotCrashOrLeaveScreen() {
        let headline = app.staticTexts["Opening camera..."]
        XCTAssertTrue(headline.waitForExistence(timeout: 3))

        // On the simulator `openCamera()` is guarded by `hasPhysicalCamera`
        // and does nothing, so tapping should leave the placeholder in place.
        headline.tap()

        XCTAssertTrue(
            headline.waitForExistence(timeout: 2),
            "Placeholder should remain visible after tapping on simulator"
        )
        XCTAssertTrue(
            app.tabBars.buttons["Capture"].isSelected,
            "User should still be on the Capture tab after tapping placeholder"
        )
    }

    // MARK: - Navigation to MoleSegmentationView
    //
    // The production `-UITest_InjectCapturedImage <base64-PNG>` launch
    // argument is consumed by ContentView, which decodes the payload into a
    // UIImage and hands it to `CameraView(preloadedImage:)`. That triggers
    // the same `onChange` path a real capture would

    func testCapturedImageNavigatesToMoleSegmentationView() {
        app.terminate()
        app.launchArguments = [
            "-SkipModelLoading",
            "-UITest_InMemoryStore",
            "-UITest_InjectCapturedImage",
            Self.onePixelPNGBase64(),
        ]
        app.launch()

        Helpers.openCaptureTab(in: app)

        var segmentationRoot = app.descendants(matching: .any)
            .matching(identifier: "moleSegmentationView")
            .firstMatch
        var bottomActionArea = app.otherElements["moleSegmentationBottomActionArea"]
        var primaryActionButton = app.buttons["moleSegmentationPrimaryActionButton"]

        if !segmentationRoot.waitForExistence(timeout: 3) {
            Thread.sleep(forTimeInterval: 20)
            Helpers.openCaptureTab(in: app)

            segmentationRoot = app.descendants(matching: .any)
                .matching(identifier: "moleSegmentationView")
                .firstMatch
            bottomActionArea = app.otherElements["moleSegmentationBottomActionArea"]
            primaryActionButton = app.buttons["moleSegmentationPrimaryActionButton"]
        }

        XCTAssertTrue(
            segmentationRoot.waitForExistence(timeout: 3),
            "CameraView should push MoleSegmentationView once `capturedImage` is set"
        )
        XCTAssertTrue(
            bottomActionArea.waitForExistence(timeout: 3),
            "MoleSegmentationView should render its bottom action area after navigation"
        )
        XCTAssertTrue(
            primaryActionButton.waitForExistence(timeout: 3),
            "MoleSegmentationView should expose its primary action button after navigation"
        )
    }

    func testSegmentationViewIsNotShownWithoutCapturedImage() {
        // Without an injected image on the simulator there's no way to
        // produce a capturedImage, so the navigation must stay on the placeholder.
        XCTAssertTrue(app.staticTexts["Opening camera..."].waitForExistence(timeout: 3))
        XCTAssertFalse(
            app.navigationBars["Mole Segmentation"].exists,
            "MoleSegmentationView must not be pushed until an image is captured"
        )
    }

    // MARK: - Fixtures

    /// Builds a 1×1 solid-gray PNG and returns it base64-encoded, so it can
    /// be passed to the app through `launchArguments`.
    private static func onePixelPNGBase64() -> String {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
        let image = renderer.image { ctx in
            UIColor.gray.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        return image.pngData()!.base64EncodedString()
    }
}
