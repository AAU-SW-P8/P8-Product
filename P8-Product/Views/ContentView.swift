//
//  ContentView.swift
//  P8-Product
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
            MoleSegmentationTestView()
                .tabItem {
                    Label("Segment", systemImage: "camera")
                }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [HistoryItem.self, Person.self], inMemory: true)
}
