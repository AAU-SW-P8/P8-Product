//
//  P8_ProductUITests.swift
//  P8-ProductUITests
//
//  Created by Simon Thordal on 31/03/2026.
//

import XCTest

final class ProductUITests: XCTestCase {
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
    }
}
