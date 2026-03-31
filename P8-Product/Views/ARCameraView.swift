//
// ARCameraView.swift
// P8-Product
//

import SwiftUI

struct ARCameraView: UIViewControllerRepresentable {
    @Binding var capturedImage: UIImage?
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> ARCameraViewController {
        let controller = ARCameraViewController()
        controller.onCapture = { image in
            capturedImage = image
            dismiss()
        }
        controller.onCancel = {
            dismiss()
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: ARCameraViewController, context: Context) {}
}
