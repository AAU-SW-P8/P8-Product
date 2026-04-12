import XCTest

extension XCUIApplication {
    func launchForUITests(file: StaticString = #filePath, line: UInt = #line) {
        launchArguments += ["-uiTesting"]
        launchEnvironment["UITEST_DISABLE_ANIMATIONS"] = "1"
        launch()

        // Replace with a real "app is ready" identifier from your app UI.
        let ready = otherElements["homeScreenRoot"]
        XCTAssertTrue(ready.waitForExistence(timeout: 30), "App did not become ready", file: file, line: line)
    }
}