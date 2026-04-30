//
// BasicCameraView.swift
// P8-Product
//

import SwiftUI

/// SwiftUI wrapper around `UIImagePickerController` used as the fallback
/// camera on devices without LiDAR.
///
/// Presents the system camera and forwards the captured photo back to the
/// caller through a binding, dismissing itself on either capture or cancel.
/// Unlike `ARCameraView` this path provides no depth or confidence data — it
/// only returns the color image.
struct BasicCameraView: UIViewControllerRepresentable {
  /// Receives the photo produced by the system camera.
  @Binding var capturedImage: UIImage?
  /// SwiftUI dismissal action used to close the full-screen cover after capture or cancellation.
  @Environment(\.dismiss) var dismiss

  /// Creates the `Coordinator` that acts as the picker's delegate.
  ///
  /// - Returns: A new coordinator holding a reference back to this view so
  ///   it can forward delegate callbacks into the SwiftUI bindings.
  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  /// Builds the underlying `UIImagePickerController` configured for camera
  /// capture and wires up the coordinator as its delegate.
  ///
  /// - Parameter context: The representable context provided by SwiftUI.
  /// - Returns: A `UIImagePickerController` ready to present the system
  ///   camera UI.
  func makeUIViewController(context: Context) -> UIImagePickerController {
    let picker = UIImagePickerController()
    picker.sourceType = .camera
    picker.delegate = context.coordinator
    return picker
  }

  /// Required by `UIViewControllerRepresentable` but intentionally empty:
  /// the picker is fully configured on creation and has no SwiftUI-owned
  /// state that needs to be pushed down on update.
  ///
  /// - Parameters:
  ///   - uiViewController: The picker created in `makeUIViewController`.
  ///   - context: The representable context provided by SwiftUI.
  func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

  /// Delegate bridge between `UIImagePickerController`'s UIKit callbacks and
  /// the SwiftUI bindings owned by `BasicCameraView`.
  class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    let parent: BasicCameraView

    /// Creates a coordinator bound to the given view.
    ///
    /// - Parameter parent: The `BasicCameraView` whose bindings should
    ///   receive the captured image and dismissal signals.
    init(_ parent: BasicCameraView) {
      self.parent = parent
    }

    /// Called by UIKit when the user confirms a photo. Extracts the
    /// original (unedited) image, writes it to the binding, and dismisses
    /// the picker.
    ///
    /// - Parameters:
    ///   - picker: The picker that finished capture.
    ///   - info: Media info dictionary provided by UIKit; `.originalImage`
    ///     is read for the captured photo.
    func imagePickerController(
      _ picker: UIImagePickerController,
      didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
      if let image = info[.originalImage] as? UIImage {
        parent.capturedImage = image
      }
      parent.dismiss()
    }

    /// Called by UIKit when the user cancels capture. Dismisses the
    /// picker without updating the captured-image binding.
    ///
    /// - Parameter picker: The picker that was cancelled.
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
      parent.dismiss()
    }
  }
}
