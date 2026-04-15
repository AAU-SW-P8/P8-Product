
import XCTest

final class Helpers {

	static func openOverviewTab(
		in app: XCUIApplication,
		file: StaticString = #filePath,
		line: UInt = #line
	) {
		app.tabBars.buttons["Overview"].tap()
		XCTAssertTrue(app.staticTexts["Mole Overview"].waitForExistence(timeout: 3), file: file, line: line)
	}

	static func openReminderTab(
		in app: XCUIApplication,
		file: StaticString = #filePath,
		line: UInt = #line
	) {
		app.tabBars.buttons["Reminder"].tap()
		XCTAssertTrue(app.tabBars.buttons["Reminder"].exists, file: file, line: line)
	}

	static func openMoleDetail(
		person personName: String,
		mole moleName: String,
		in app: XCUIApplication,
		file: StaticString = #filePath,
		line: UInt = #line
	) {
		openOverviewTab(in: app, file: file, line: line)
		moveOverviewSelection(to: personName, in: app)

		let moleLabel = app.staticTexts[moleName].firstMatch
		XCTAssertTrue(moleLabel.waitForExistence(timeout: 3), "Could not find mole row: \(moleName)", file: file, line: line)
		moleLabel.tap()

		XCTAssertTrue(
			app.segmentedControls["moleDetailPagePicker"].waitForExistence(timeout: 3),
			"Mole detail page picker should be visible after opening detail",
			file: file,
			line: line
		)
	}

	static func switchToEvolution(in app: XCUIApplication) {
		let pagePicker = app.segmentedControls["moleDetailPagePicker"]
		XCTAssertTrue(pagePicker.waitForExistence(timeout: 3))
		pagePicker.buttons["Evolution"].tap()
	}

	static func switchToDetail(in app: XCUIApplication) {
		let pagePicker = app.segmentedControls["moleDetailPagePicker"]
		XCTAssertTrue(pagePicker.waitForExistence(timeout: 3))
		pagePicker.buttons["Detail"].tap()
	}

	static func chooseMoleFromDetailTitle(_ moleName: String, in app: XCUIApplication) {
		let titleMenu = app.buttons["moleDetailMolePicker"]
		XCTAssertTrue(titleMenu.waitForExistence(timeout: 3))
		titleMenu.tap()
		app.buttons[moleName].tap()
	}

	static func selectPerson(_ name: String, in app: XCUIApplication) {
		moveOverviewSelection(to: name, in: app)
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

	static func selectAlexLeftArmMole(in app: XCUIApplication) {
		openMoleDetail(person: "Alex", mole: "Left Arm Mole", in: app)
		switchToEvolution(in: app)

		XCTAssertTrue(
			app.otherElements["dualCarouselContainer"].waitForExistence(timeout: 5),
			"Dual carousel container should appear after selecting Left Arm Mole"
		)
	}

	static func selectAlexBackMole(in app: XCUIApplication) {
		openMoleDetail(person: "Alex", mole: "Back Mole", in: app)
		switchToEvolution(in: app)
	}

	static func deletePerson(_ name: String, in app: XCUIApplication) {
		let personCell = app.staticTexts[name]
		XCTAssertTrue(personCell.waitForExistence(timeout: 3), "Person \(name) should exist before deletion")

		personCell.press(forDuration: 1.0)
		app.buttons["Delete"].tap()
		app.alerts.buttons["Delete"].tap()
	}
}
