//
// ContentView.swift
// P8-Product
//

import SwiftUI
import SwiftData
import UIKit

struct ContentView: View {
    @StateObject private var modelLoader = SAM3ModelLoader.shared

    private var skipModelLoading: Bool {
        ProcessInfo.processInfo.arguments.contains("-SkipModelLoading")
    }

    /// Reads a base64-encoded PNG from the launch argument that follows
    /// `-UITest_InjectCapturedImage`, returning it as a `UIImage`. Returns
    /// `nil` when the flag is absent or the payload cannot be decoded.
    private static var preloadedCameraImage: UIImage? {
        let args = ProcessInfo.processInfo.arguments
        guard let flagIndex = args.firstIndex(of: "-UITest_InjectCapturedImage"),
              flagIndex + 1 < args.count,
              let data = Data(base64Encoded: args[flagIndex + 1]) else {
            return nil
        }
        return UIImage(data: data)
    }

    var body: some View {
        Group {
            if skipModelLoading {
                mainTabView
            } else if let error = modelLoader.error {
                errorView(error)
            } else if  modelLoader.isLoading || modelLoader.segmentor == nil {
                loadingView
            } else {
                mainTabView
            }
        }
        .task {
            guard !skipModelLoading else { return }
            await modelLoader.loadModel()
        }
    }

    private var mainTabView: some View {
        TabView {
            OverviewView()
                .tabItem {
                    Label("Overview", systemImage: "square.grid.2x2")
                }

            ReminderView()
                .tabItem {
                    Label("Reminder", systemImage: "clock")
                }

            CameraView(preloadedImage: Self.preloadedCameraImage)
                .tabItem {
                    Label("Capture", systemImage: "camera")
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
