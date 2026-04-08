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
        app.launch()
    }

    private var personPickerButton: XCUIElement {
        let labels = ["Person", "Alex", "Jordan", "Taylor"]

        for label in labels {
            let button = app.buttons.matching(
                NSPredicate(format: "label CONTAINS[c] %@", label)
            ).firstMatch
            if button.exists {
                return button
            }
        }

        return app.buttons.firstMatch
    }

    private var overviewNextPersonButton: XCUIElement {
        app.buttons["chevron.right"]
    }

    private func openCompareTab() {
        app.tabBars.buttons["Compare"].tap()
        XCTAssertTrue(app.staticTexts["Compare"].waitForExistence(timeout: 3))
    }

    private func openOverviewTab() {
        app.tabBars.buttons["Overview"].tap()
        XCTAssertTrue(app.staticTexts["Mole Overview"].waitForExistence(timeout: 3))
    }

    private func selectComparePerson(_ name: String) {
        personPickerButton.tap()
        app.buttons[name].tap()
    }

    private func moveOverviewSelection(to name: String) {
        let expectedSelections = ["Alex", "Jordan", "Taylor"]
        guard let targetIndex = expectedSelections.firstIndex(of: name) else {
            XCTFail("Unknown person: \(name)")
            return
        }

        for _ in 0..<targetIndex {
            overviewNextPersonButton.tap()
        }
    }

    func testSelectedPersonPersistsBetweenTabs() {
        openOverviewTab()

        XCTAssertTrue(app.staticTexts["Alex"].waitForExistence(timeout: 3),
                      "Overview should start on Alex in the seeded data")

        openCompareTab()

        XCTAssertTrue(
            app.staticTexts["selectMolePrompt"].waitForExistence(timeout: 3),
            "Compare tab should reflect the selected person"
        )

        openOverviewTab()

        XCTAssertTrue(
            app.staticTexts["Alex"].waitForExistence(timeout: 3),
            "Overview tab should keep the selected person when switching tabs"
        )

        openCompareTab()
        let selectedPersonButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Alex")
        ).firstMatch
        XCTAssertTrue(
            selectedPersonButton.waitForExistence(timeout: 3),
            "Compare tab should still show Alex after returning from Overview"
        )
    }

    func testChangingPersonInComparePersistsBackToOverview() {
        openOverviewTab()

        XCTAssertTrue(app.staticTexts["Alex"].waitForExistence(timeout: 3),
                      "Overview should begin with Alex selected")

        openCompareTab()

        selectComparePerson("Alex")
        XCTAssertTrue(
            app.staticTexts["selectMolePrompt"].waitForExistence(timeout: 3),
            "Compare should show Alex before switching people"
        )

        selectComparePerson("Jordan")

        openOverviewTab()

        XCTAssertTrue(
            app.staticTexts["Jordan"].waitForExistence(timeout: 3),
            "Overview should reflect the selection made in Compare"
        )
    }

    func testDeletingTaylorFallsBackToAlexAcrossTabs() {
        openOverviewTab()

        moveOverviewSelection(to: "Taylor")

        XCTAssertTrue(
            app.staticTexts["Taylor"].waitForExistence(timeout: 3),
            "Overview should be on Taylor before deletion"
        )

        app.staticTexts["Taylor"].press(forDuration: 1.0)
        app.buttons["Delete"].tap()
        app.alerts["Delete Person"].buttons["Delete"].tap()

        XCTAssertTrue(
            app.staticTexts["Alex"].waitForExistence(timeout: 3),
            "Overview should fall back to Alex after deleting Taylor"
        )

        openCompareTab()

        XCTAssertTrue(
            app.staticTexts["selectMolePrompt"].waitForExistence(timeout: 3),
            "Compare should now be back on the fallback person"
        )

        let alexButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Alex")
        ).firstMatch
        XCTAssertTrue(
            alexButton.waitForExistence(timeout: 3),
            "Compare should default back to Alex after Taylor is deleted"
        )
        XCTAssertFalse(
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Taylor")).firstMatch.exists,
            "Taylor should no longer be available after deletion"
        )
    }

}