//
//  TabStateUITests.swift
//  P8-ProductUITests
//

import XCTest

/// UI tests verifying that selected-person state persists correctly when switching between tabs.
final class TabStateUITests: XCTestCase {

  /// The application instance under test.
  private var app: XCUIApplication!

  /// Sets up a fresh in-memory store for each test, skipping automatic model loading to ensure a clean state.
  /// This is necessary to prevent data from previous test runs from affecting subsequent tests.
  override func setUpWithError() throws {
    continueAfterFailure = false
    app = XCUIApplication()
    app.launchArguments.append("-UITest_InMemoryStore")
    app.launchArguments.append("-SkipModelLoading")
    app.launch()
  }

  /// Verifies the selected person is preserved when switching between the Overview and Reminder tabs.
  func testSelectedPersonPersistsBetweenTabs() {
    Helpers.openOverviewTab(in: app)

    XCTAssertTrue(
      app.staticTexts["Alex"].waitForExistence(timeout: 3),
      "Overview should start on Alex in the seeded data")

    Helpers.openReminderTab(in: app)

    XCTAssertTrue(
      app.tabBars.buttons["Reminder"].waitForExistence(timeout: 3),
      "Reminder tab should open successfully"
    )

    Helpers.openOverviewTab(in: app)

    XCTAssertTrue(
      app.staticTexts["Alex"].waitForExistence(timeout: 3),
      "Overview tab should keep the selected person when switching tabs"
    )
  }

  /// Verifies the selected person is preserved in the overview after opening a mole detail and returning.
  func testChangingPersonInOverviewPersistsAfterOpeningDetail() {
    Helpers.openOverviewTab(in: app)

    XCTAssertTrue(
      app.staticTexts["Alex"].waitForExistence(timeout: 3),
      "Overview should begin with Alex selected")

    Helpers.movePersonSelection(to: "Jordan", in: app)
    Helpers.openMoleDetail(person: "Jordan", mole: "Face Mole", in: app)

    Helpers.openOverviewTab(in: app)

    XCTAssertTrue(
      app.staticTexts["Jordan"].waitForExistence(timeout: 3),
      "Overview should reflect the selection after visiting detail"
    )
  }

  /// Verifies that deleting the selected person falls back the selection to the first available person across tabs.
  func testDeletingTaylorFallsBackToAlexAcrossTabs() {
    Helpers.openOverviewTab(in: app)

    Helpers.movePersonSelection(to: "Taylor", in: app)

    XCTAssertTrue(
      app.staticTexts["Taylor"].waitForExistence(timeout: 3),
      "Overview should be on Taylor before deletion"
    )

    Helpers.openReminderTab(in: app)
    XCTAssertTrue(
      app.tabBars.buttons["Reminder"].waitForExistence(timeout: 3),
      "Reminder should open before returning to delete"
    )

    Helpers.openOverviewTab(in: app)
    Helpers.deletePerson("Taylor", in: app)

    XCTAssertTrue(
      app.staticTexts["Alex"].waitForExistence(timeout: 3),
      "Overview should fall back to Alex after deleting Taylor"
    )

    Helpers.openReminderTab(in: app)
    Helpers.openOverviewTab(in: app)
    XCTAssertTrue(
      app.staticTexts["Alex"].waitForExistence(timeout: 3),
      "Overview should still be Alex after tab switches"
    )
  }

}
