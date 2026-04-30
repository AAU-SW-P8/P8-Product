//
// ARCameraView.swift
// P8-Product
//

import CoreVideo
import SwiftUI
import simd

/// SwiftUI wrapper around `ARCameraViewController` that exposes the LiDAR
/// capture flow to the rest of the app.
///
/// Bridges the UIKit-based AR capture controller into a SwiftUI view hierarchy
/// and forwards the captured photo along with its per-pixel depth and confidence
/// maps back to the caller via bindings
struct ARCameraView: UIViewControllerRepresentable {
  /// Receives the color photo produced by the AR session.
  @Binding var capturedImage: UIImage?
  /// Receives the LiDAR depth map aligned with `capturedImage`
  @Binding var capturedDepthMap: CVPixelBuffer?
  /// Receives the per-pixel confidence values for `capturedDepthMap`
  @Binding var capturedConfidenceMap: CVPixelBuffer?
  /// Receives the camera intrinsics matrix aligned with the capture.
  @Binding var capturedIntrinsics: simd_float3x3?
  /// SwiftUI dismissal action used to close the full-screen cover after capture or cancellation.
  @Environment(\.dismiss) var dismiss

  /// Creates the underlying `ARCameraViewController` and wires its capture
  /// and cancel callbacks to update the bindings and dismiss the view.
  ///
  /// - Parameter context: The representable context provided by SwiftUI.
  /// - Returns: A fully configured `ARCameraViewController` ready to run the
  ///   AR session and deliver captured frames back through the bindings.
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

  /// Required by `UIViewControllerRepresentable` but intentionally empty
  ///
  /// - Parameters:
  ///   - uiViewController: The controller created in `makeUIViewController`.
  ///   - context: The representable context provided by SwiftUI.
  func updateUIViewController(_ uiViewController: ARCameraViewController, context: Context) {}
}
