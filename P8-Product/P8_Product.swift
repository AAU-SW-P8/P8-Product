//
//  P8_Product_TestApp.swift
//  P8-Product
//

import SwiftUI
import SwiftData
import UIKit

@main
struct P8_Product: App {
    var container: ModelContainer = {
        if ProcessInfo.processInfo.environment["CI"] == "true" { // Use in-memory store for CI testing
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            return try! ModelContainer(for: MyModel.self, configurations: config)
        } else {
            return try! ModelContainer(for: MyModel.self)
        }
    }()
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [HistoryItem.self, Person.self])
    }
}
