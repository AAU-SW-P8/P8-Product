//
// CameraView.swift
// P8-Product
//

import SwiftUI
import ARKit

struct CameraView: View {
    @State private var capturedImage: UIImage?
    @State private var showCamera = false
    @State private var showSegmentation = false
    private let supportsARCapture = ARWorldTrackingConfiguration.isSupported
        && ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
    private let hasPhysicalCamera = UIImagePickerController.isSourceTypeAvailable(.camera)

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

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
            .onAppear {
                openCamera()
            }
            .onTapGesture {
                if !showCamera && !showSegmentation {
                    openCamera()
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                if supportsARCapture {
                    ARCameraView(capturedImage: $capturedImage)
                        .ignoresSafeArea()
                } else {
                    SimpleCameraView(capturedImage: $capturedImage)
                        .ignoresSafeArea()
                }
            }
            .fullScreenCover(isPresented: $showSegmentation) {
                if let capturedImage {
                    MoleSegmentationTestView(inputImage: capturedImage)
                }
            }
            .onChange(of: capturedImage) {
                if capturedImage != nil {
                    showSegmentation = true
                }
            }
    }

    private func openCamera() {
        guard hasPhysicalCamera else { return }
        showCamera = true
    }
}
