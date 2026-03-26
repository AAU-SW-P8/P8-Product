//
//  P8_Product_TestApp.swift
//  P8-Product
//

import SwiftUI
import SwiftData
import UIKit

@main
struct P8_Product: App {
    
    let dataController = DataController.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(dataController.container)
    }
    
}
