//
//  P8_ProductUITests.swift
//  P8-ProductUITests
//

import XCTest

final class ProductUITests: XCTestCase {

    func testLaunchPerformance() throws {
        #if targetEnvironment(simulator)
        // Skip in CI because simulator/app termination is flaky on hosted runners.
        if ProcessInfo.processInfo.environment["CI"] == "true" {
            throw XCTSkip("Skipping launch performance test on CI (terminate/launch is flaky on hosted simulators).")
        }
        #endif

        if #available(iOS 13.0, *) {
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                let app = XCUIApplication()
                app.launch()
            }
        } else {
            throw XCTSkip("Launch performance metrics require iOS 13+.")
        }
    }
}
