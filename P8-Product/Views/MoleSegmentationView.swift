//
//  MoleSegmentationTestView.swift
//  P8-Product
//
//  Created by Simon Thordal on 3/24/26.
//

import SwiftUI
import CoreML

/// A view that automatically segments moles using SAM3 with the text prompt "moles".
///
/// When the view appears, the SAM3 pipeline loads and immediately runs segmentation
/// on the test image — no tap or manual interaction needed. Detected mole regions
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
    @State private var statusMessage: String = "Loading models…"

    /// Holds the localised error message when something fails.
    @State private var errorMessage: String?

    /// Controls presentation of the error alert.
    @State private var showError = false

    /// The loaded SAM3 model wrapper, initialised asynchronously on appear.
    @State private var segmentor: MoleSegmentor?

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
            .task { await loadAndSegment() }
        }
    }

    // MARK: - Image layer

    /// Renders the base image with the mask overlay composited on top.
    @ViewBuilder
    private func imageContent(image: UIImage) -> some View {
        GeometryReader { geometry in
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width, height: geometry.size.height)

                if let mask = maskOverlay {
                    Image(uiImage: mask)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .allowsHitTesting(false)
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

    /// Loads the SAM3 models, then immediately segments the test image.
    private func loadAndSegment() async {
        guard testImage != nil else { return }

        isProcessing = true
        statusMessage = "Loading SAM3 models…"

        do {
            let seg = try await MoleSegmentor()
            segmentor = seg
            statusMessage = "Segmenting…"

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
    private func resegment() {
        guard let segmentor, let image = testImage else { return }
        Task {
            isProcessing = true
            statusMessage = "Segmenting…"
            segmentor.clearCache()

            do {
                let mask = try segmentor.segment(image: image)
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
    }

    /// Removes the current mask overlay and clears the model's cache.
    private func clearSegmentation() {
        maskOverlay = nil
        statusMessage = "Cleared"
        segmentor?.clearCache()
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
                    .disabled(segmentor == nil || isProcessing)
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
