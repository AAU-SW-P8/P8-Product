//
// CameraView.swift
// P8-Product
//

import SwiftUI
import ARKit

/// The main capture tab. Opens the camera automatically on appear, waits for
/// the user to take a photo, then hands the image to `MoleSegmentationTestView`.
///
/// On LiDAR-equipped devices the AR camera (with distance guidance) is used;
/// on other devices a standard `UIImagePickerController` camera is presented.
/// In the Simulator (no physical camera) the view stays on a placeholder screen.
struct CameraView: View {

    /// The photo returned by the camera after the user confirms it.
    @State private var capturedImage: UIImage?

    /// Depth map from the AR camera's LiDAR sensor (nil for non-AR captures).
    @State private var capturedDepthMap: CVPixelBuffer?

    /// Confidence map for the depth data (nil for non-AR captures).
    @State private var capturedConfidenceMap: CVPixelBuffer?

    /// Controls presentation of the camera full-screen cover.
    @State private var showCamera = false

    /// Controls navigation to the segmentation view.
    @State private var showSegmentation = false

    /// Whether the device has LiDAR (AR world tracking + mesh reconstruction).
    private let supportsARCapture = ARWorldTrackingConfiguration.isSupported
        && ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)

    /// Whether a physical camera is available (false in Simulator).
    private let hasPhysicalCamera = UIImagePickerController.isSourceTypeAvailable(.camera)

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()

                // Shown briefly while the camera is opening, or when the user
                // dismisses the camera without taking a photo.
                VStack(spacing: 12) {
                    Text("Opening camera...")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("If camera is closed, tap anywhere to open again")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                .multilineTextAlignment(.center)
                .padding(24)
            }
            // Let the user re-open the camera by tapping the background.
            .onTapGesture {
                if !showCamera && !showSegmentation {
                    openCamera()
                }
            }
            // Navigate to segmentation within the NavigationStack so the
            // tab bar stays visible and the user can navigate back.
            .navigationDestination(isPresented: $showSegmentation) {
                if let capturedImage {
                    MoleSegmentationView(inputImage: capturedImage,
                                         depthMap: capturedDepthMap,
                                         confidenceMap: capturedConfidenceMap)
                }
            }
        }
        // Open the camera as soon as the tab appears.
        .onAppear {
            openCamera()
        }
        // Camera: choose AR or simple depending on device capabilities.
        .fullScreenCover(isPresented: $showCamera) {
            if supportsARCapture {
                ARCameraView(capturedImage: $capturedImage,
                             capturedDepthMap: $capturedDepthMap,
                             capturedConfidenceMap: $capturedConfidenceMap)
                    .ignoresSafeArea()
            } else {
                SimpleCameraView(capturedImage: $capturedImage)
                    .ignoresSafeArea()
            }
        }
        // As soon as the camera sets capturedImage, move to segmentation.
        .onChange(of: capturedImage) {
            if capturedImage != nil {
                showSegmentation = true
            }
        }
        // When the user taps back from segmentation, reset state and
        // reopen the camera instead of landing on the placeholder.
        .onChange(of: showSegmentation) { _, isShown in
            if !isShown {
                capturedImage = nil
                capturedDepthMap = nil
                capturedConfidenceMap = nil
                openCamera()
            }
        }
    }

    /// Presents the camera if the device has one.
    private func openCamera() {
        guard hasPhysicalCamera else { return }
        showCamera = true
    }
}
