//
// ContentView.swift
// P8-Product
//

import SwiftUI
import SwiftData
import UIKit

struct ContentView: View {
    @StateObject private var modelLoader = SAM3ModelLoader.shared
    
    var body: some View {
        Group {
            if let error = modelLoader.error {
                errorView(error)
            } else if  modelLoader.isLoading || modelLoader.segmentor == nil {
                loadingView
            } else {
                mainTabView
            }
        }
        .task {
            await modelLoader.loadModel()
        }
    }
    
    private var mainTabView: some View {
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
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 60))
                .foregroundStyle(.blue)
                .symbolEffect(.pulse)
            
            Text("Initializing AI Models…")
                .font(.headline)
            
            ProgressView()
                .controlSize(.large)
            
            Text("This may take a moment on first launch.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
    
    private func errorView(_ error: Error) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.red)
            
            Text("Failed to Load AI Models")
                .font(.headline)
            
            Text(error.localizedDescription)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Retry") {
                Task {
                    await modelLoader.loadModel()
                }
            }
            .buttonStyle(.borderedProminent)
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
