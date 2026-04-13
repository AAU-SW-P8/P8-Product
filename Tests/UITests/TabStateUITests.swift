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

        Helpers.openCompareTab(in: app)

        XCTAssertTrue(
            app.staticTexts["selectMolePrompt"].waitForExistence(timeout: 3),
            "Compare tab should reflect the selected person"
        )

        Helpers.openOverviewTab(in: app)

        XCTAssertTrue(
            app.staticTexts["Alex"].waitForExistence(timeout: 3),
            "Overview tab should keep the selected person when switching tabs"
        )

        Helpers.openCompareTab(in: app)
        
        XCTAssertTrue(
            Helpers.selectedPersonButton(named: "Alex", in: app).waitForExistence(timeout: 3),
            "Compare tab should still show Alex after returning from Overview"
        )
    }

    func testChangingPersonInComparePersistsBackToOverview() {
        Helpers.openOverviewTab(in: app)

        XCTAssertTrue(app.staticTexts["Alex"].waitForExistence(timeout: 3),
                      "Overview should begin with Alex selected")

        Helpers.openCompareTab(in: app)

        Helpers.selectPerson("Alex", in: app)
        XCTAssertTrue(
            app.staticTexts["selectMolePrompt"].waitForExistence(timeout: 3),
            "Compare should show Alex before switching people"
        )

        Helpers.selectPerson("Jordan", in: app)

        Helpers.openOverviewTab(in: app)

        XCTAssertTrue(
            app.staticTexts["Jordan"].waitForExistence(timeout: 3),
            "Overview should reflect the selection made in Compare"
        )
    }

    func testDeletingTaylorFallsBackToAlexAcrossTabs() {
        Helpers.openOverviewTab(in: app)

        Helpers.moveOverviewSelection(to: "Taylor", in: app)

        XCTAssertTrue(
            app.staticTexts["Taylor"].waitForExistence(timeout: 3),
            "Overview should be on Taylor before deletion"
        )
        Helpers.openCompareTab(in: app)
        XCTAssertTrue(
            app.staticTexts["Taylor"].waitForExistence(timeout: 3),
            "Compare should also show Taylor before deletion"
        )

        Helpers.openOverviewTab(in: app)
        Helpers.deletePerson("Taylor", in: app)

        XCTAssertTrue(
            app.staticTexts["Alex"].waitForExistence(timeout: 3),
            "Overview should fall back to Alex after deleting Taylor"
        )

        Helpers.openCompareTab(in: app)
        XCTAssertTrue(
            app.staticTexts["Alex"].waitForExistence(timeout: 3),
            "Compare should also fall back to Alex after deleting Taylor"
        )
    }

}
