//
// ContentView.swift
// P8-Product
//

import SwiftUI
import SwiftData
import UIKit

struct ContentView: View {
    var body: some View {
        TabView {
            OverviewView()
                .tabItem {
                    Label("Overview", systemImage: "square.grid.2x2")
                }

            CompareView()
                .tabItem {
                    Label("Compare", systemImage: "book.pages")
                }

            ReminderView()
                .tabItem {
                    Label("Reminder", systemImage: "clock")
                }
                
            CameraView()
                .tabItem {
                    Label("Capture", systemImage: "camera")
                }
            MoleSegmentationTestView(inputImage: UIImage(named: "test_mole_image"))
                .tabItem {
                    Label("Segment", systemImage: "camera")
                }
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
    for: Person.self,
        Mole.self,
        MoleInstance.self,
        MoleScan.self,
        configurations: config
    )
    
    // Seed preview data
    Task { @MainActor in
        MockData.insertSampleData(into: container.mainContext)
    }
    
    return ContentView()
        .modelContainer(container)
}
