//
// ARCameraView.swift
// P8-Product
//

import SwiftUI
import CoreVideo
import simd

struct ARCameraView: UIViewControllerRepresentable {
    @Binding var capturedImage: UIImage?
    @Binding var capturedDepthMap: CVPixelBuffer?
    @Binding var capturedConfidenceMap: CVPixelBuffer?
    @Binding var capturedIntrinsics: simd_float3x3?
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> ARCameraViewController {
        let controller = ARCameraViewController()
        controller.onCapture = { image, depthMap, confidenceMap, intrinsics in
            capturedImage = image
            capturedDepthMap = depthMap
            capturedConfidenceMap = confidenceMap
            capturedIntrinsics = intrinsics
            dismiss()
        }
        controller.onCancel = {
            dismiss()
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: ARCameraViewController, context: Context) {}
}
