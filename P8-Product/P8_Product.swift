//
//  P8_Product.swift
//  P8-Product
//

import SwiftUI
import SwiftData

@main
struct P8_Product: App {
    
    let dataController = DataController.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(dataController.container) // Use the custom ModelContainer for the app
    }
    
}
