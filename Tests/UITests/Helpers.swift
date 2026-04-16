
import XCTest

final class Helpers {

	static func personPickerButton(
		in app: XCUIApplication,
		file: StaticString = #filePath,
		line: UInt = #line
	) -> XCUIElement {
		let identifiedButton = app.buttons["personPicker"]
		if identifiedButton.exists {
			return identifiedButton
		}

		let labels = ["Person", "Alex", "Jordan", "Taylor"]

		for label in labels {
			let button = app.buttons.matching(
				NSPredicate(format: "label CONTAINS[c] %@", label)
			).firstMatch
			if button.exists {
				return button
			}
		}

		XCTFail("Could not find person picker by accessibility identifier or known labels.", file: file, line: line)
		return identifiedButton
	}

	static func molePickerButton(in app: XCUIApplication) -> XCUIElement {
		app.buttons.matching(
			NSPredicate(format: "label CONTAINS[c] %@", "Select Mole")
		).firstMatch
	}

	static func openCompareTab(
		in app: XCUIApplication,
		file: StaticString = #filePath,
		line: UInt = #line
	) {
		app.tabBars.buttons["Compare"].tap()
		XCTAssertTrue(app.staticTexts["Compare"].waitForExistence(timeout: 3), file: file, line: line)
	}

	static func openOverviewTab(
		in app: XCUIApplication,
		file: StaticString = #filePath,
		line: UInt = #line
	) {
		app.tabBars.buttons["Overview"].tap()
		XCTAssertTrue(app.staticTexts["Mole Overview"].waitForExistence(timeout: 3), file: file, line: line)
	}

	static func openCaptureTab(in app: XCUIApplication) {
		app.tabBars.buttons["Capture"].tap()
	}

	static func selectPerson(_ name: String, in app: XCUIApplication) {
		personPickerButton(in: app).tap()
		app.buttons[name].tap()
	}

	static func selectMole(_ name: String, in app: XCUIApplication) {
		molePickerButton(in: app).tap()
		app.buttons[name].tap()
	}

	static func moveOverviewSelection(to name: String, in app: XCUIApplication) {
		let expectedSelections = ["Alex", "Jordan", "Taylor"]
		guard let targetIndex = expectedSelections.firstIndex(of: name) else {
			XCTFail("Unknown person: \(name)")
			return
		}

		let nextButton = app.buttons["chevron.right"]
		for _ in 0..<targetIndex {
			nextButton.tap()
		}
	}

	static func selectedPersonButton(named name: String, in app: XCUIApplication) -> XCUIElement {
		app.buttons.matching(
			NSPredicate(format: "label CONTAINS[c] %@", name)
		).firstMatch
	}

	static func selectAlexLeftArmMole(in app: XCUIApplication) {
		selectPerson("Alex", in: app)
		selectMole("Left Arm Mole", in: app)

		XCTAssertTrue(
			app.otherElements["dualCarouselContainer"].waitForExistence(timeout: 5),
			"Dual carousel container should appear after selecting Left Arm Mole"
		)
	}

	static func selectAlexBackMole(in app: XCUIApplication) {
		selectPerson("Alex", in: app)
		selectMole("Back Mole", in: app)
	}

	static func deletePerson(_ name: String, in app: XCUIApplication) {
		let personCell = app.staticTexts[name]
		XCTAssertTrue(personCell.waitForExistence(timeout: 3), "Person \(name) should exist before deletion")

		personCell.press(forDuration: 1.0)
		app.buttons["Delete"].tap()
		app.alerts.buttons["Delete"].tap()
	}
}
