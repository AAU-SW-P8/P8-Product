//
//  P8_Product.swift
//  P8-Product
//

import SwiftData
import SwiftUI

/// The application entry point.
@main
struct P8_Product: App {
  /// The shared data controller that owns the SwiftData model container.
  let dataController = DataController.shared
  /// The root scene containing the main content view.
  var body: some Scene {
    WindowGroup {
      ContentView()
    }
    .modelContainer(dataController.container)  // Use the custom ModelContainer for the app
  }

}
