//
//  TabStateUITests.swift
//  P8-ProductUITests
//

import XCTest

final class TabStateUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("-UITest_InMemoryStore")
        app.launchArguments.append("-SkipModelLoading")
        app.launch()
    }

    func testSelectedPersonPersistsBetweenTabs() {
        Helpers.openOverviewTab(in: app)

        XCTAssertTrue(app.staticTexts["Alex"].waitForExistence(timeout: 3),
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

    func testChangingPersonInOverviewPersistsAfterOpeningDetail() {
        Helpers.openOverviewTab(in: app)

        XCTAssertTrue(app.staticTexts["Alex"].waitForExistence(timeout: 3),
                      "Overview should begin with Alex selected")

        Helpers.moveOverviewSelection(to: "Jordan", in: app)
        Helpers.openMoleDetail(person: "Jordan", mole: "Face Mole", in: app)

        Helpers.openOverviewTab(in: app)

        XCTAssertTrue(
            app.staticTexts["Jordan"].waitForExistence(timeout: 3),
            "Overview should reflect the selection after visiting detail"
        )
    }

    func testDeletingTaylorFallsBackToAlexAcrossTabs() {
        Helpers.openOverviewTab(in: app)

        Helpers.moveOverviewSelection(to: "Taylor", in: app)

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
