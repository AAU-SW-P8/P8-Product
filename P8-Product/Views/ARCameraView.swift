//
// ARCameraView.swift
// P8-Product
//

import SwiftUI

struct ARCameraView: UIViewControllerRepresentable {
    @Binding var capturedImage: UIImage?
    @Binding var capturedDepthMap: CVPixelBuffer?
    @Binding var capturedConfidenceMap: CVPixelBuffer?
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> ARCameraViewController {
        let controller = ARCameraViewController()
        controller.onCapture = { image, depthMap, confidenceMap in
            capturedImage = image
            capturedDepthMap = depthMap
            capturedConfidenceMap = confidenceMap
            dismiss()
        }
        controller.onCancel = {
            dismiss()
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: ARCameraViewController, context: Context) {}
}
