//
//  P8_Product_TestApp.swift
//  P8-Product-Test
//

import SwiftUI
import SwiftData
import UIKit

@main
struct P8_Product_TestApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [HistoryItem.self, Person.self])
    }
}
