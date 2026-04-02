//
//  MoleSegmentationView.swift
//  P8-Product
//
//  Created by Simon Thordal on 3/24/26.
//

import SwiftUI

/// A view that automatically segments moles using SAM3 with the text prompt "moles".
///
/// When the view appears, it uses the pre-loaded SAM3 pipeline from SAM3ModelLoader
/// and immediately runs segmentation on the test image. Detected mole regions
/// are shown as a semi-transparent red overlay on top of the original image.
struct MoleSegmentationTestView: View {

    // MARK: - State

    /// The image to segment. Replace with the image captured by the camera.
    @State private var testImage: UIImage? = UIImage(named: "Image")

    /// Combined mask overlay for all detected moles.
    @State private var maskOverlay: UIImage?

    /// `true` while models are loading or segmentation is running.
    @State private var isProcessing = false

    /// Status text shown beneath the image.
    @State private var statusMessage: String = "Waiting for model…"

    /// Holds the localised error message when something fails.
    @State private var errorMessage: String?

    /// Controls presentation of the error alert.
    @State private var showError = false

    /// Access the global SAM3 model loader
    @ObservedObject private var modelLoader = SAM3ModelLoader.shared

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                if let image = testImage {
                    imageContent(image: image)
                } else {
                    noImagePlaceholder
                }

                if isProcessing {
                    loadingOverlay
                }
            }
            .navigationTitle("Mole Segmentation")
            .toolbar { toolbarContent }
            .alert("Error", isPresented: $showError) {
                Button("OK") { showError = false }
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
            .task {
                await runInitialSegmentation()
            }
        }
    }

    // MARK: - Image layer

    /// Renders the base image with the mask overlay composited on top.
    @ViewBuilder
    private func imageContent(image: UIImage) -> some View {
        GeometryReader { geometry in
            ZStack {
                if let mask = maskOverlay {
                    // Render the fully composited annotated image returned by MoleSegmentor
                    Image(uiImage: mask)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .allowsHitTesting(false)
                } else {
                    // Fallback: show the original image before segmentation completes
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Text(statusMessage)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)
        }
    }

    // MARK: - Actions

    /// Runs segmentation on the test image using the pre-loaded segmentor.
    private func runInitialSegmentation() async {
        guard testImage != nil else { return }
        
        // Wait for segmentor if it's still loading (though ContentView should handle this)
        while modelLoader.segmentor == nil && modelLoader.error == nil {
            try? await Task.sleep(nanoseconds: 500_000_000)
        }

        guard let seg = modelLoader.segmentor else {
            statusMessage = "AI model not ready"
            return
        }

        isProcessing = true
        statusMessage = "Segmenting…"

        do {
            guard let image = testImage else { return }
            let mask = try seg.segment(image: image)

            await MainActor.run {
                maskOverlay = mask
                statusMessage = mask != nil ? "Done — moles highlighted in red" : "No moles detected"
                isProcessing = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Segmentation failed: \(error.localizedDescription)"
                showError = true
                statusMessage = "Error"
                isProcessing = false
            }
        }
    }

    /// Re-runs segmentation (e.g. after clearing).
    @MainActor
    private func resegment() {
        guard let segmentor = modelLoader.segmentor, let image = testImage else { return }

        // These UI-related state changes are performed on the main actor.
        isProcessing = true
        statusMessage = "Segmenting…"
        segmentor.clearCache()

        // Run the model work off the main actor, then hop back to MainActor for UI updates.
        Task.detached {
            do {
                let mask = try segmentor.segment(image: image)
                await MainActor.run {
                    self.maskOverlay = mask
                    self.statusMessage = mask != nil ? "Done — moles highlighted in red" : "No moles detected"
                    self.isProcessing = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Segmentation failed: \(error.localizedDescription)"
                    self.showError = true
                    self.statusMessage = "Error"
                    self.isProcessing = false
                }
            }
        }
    }

    /// Removes the current mask overlay and clears the model's cache.
    @MainActor
    private func clearSegmentation() {
        maskOverlay = nil
        statusMessage = "Cleared"
        modelLoader.segmentor?.clearCache()
    }

    // MARK: - Supporting views

    /// Full-screen overlay shown while loading or segmenting.
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView().scaleEffect(1.5)
                Text(statusMessage)
                    .foregroundStyle(.white)
                    .font(.headline)
            }
            .padding()
            .background(.black.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    /// Shown in place of the image when `testImage` is `nil`.
    private var noImagePlaceholder: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("No test image found")
                .font(.headline)
            Text("Add an image named 'test_mole_image' to Assets.xcassets")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding()
        }
    }

    /// Navigation bar buttons.
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack {
                Button("Re-segment") { resegment() }
                    .disabled(modelLoader.segmentor == nil || isProcessing)
                Button("Clear") { clearSegmentation() }
                    .disabled(maskOverlay == nil)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    MoleSegmentationTestView()
}
