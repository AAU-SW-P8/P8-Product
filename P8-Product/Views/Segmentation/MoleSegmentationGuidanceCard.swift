import SwiftUI

/// A card view that provides step-by-step guidance for mole segmentation, adapting its content based on the current state of the segmentation process.
/// The card displays different titles and descriptions depending on whether the app is currently processing an image or has detected moles, guiding the user through the steps of scanning and selecting a mole.
/// - Parameters:
///   - index: The current step index in the guidance process.
///   - total: The total number of steps in the guidance process.
///   - title: The title of the current guidance step.
///   - description: A detailed description of the current guidance step, providing instructions to the user.
struct MoleSegmentationGuidanceStep {
  /// The index of the step.
  let index: Int
  /// The total number of steps.
  let total: Int
  /// The title of the step.
  let title: String
  /// The description of the step.
  let description: String

  /// The label for the step.
  var label: String {
    "Step \(index) of \(total)"
  }

  /// Creates a guidance step based on the current state of the segmentation process.
  static func make(isProcessing: Bool, hasDetections: Bool, hasAttemptedSegmentation: Bool = false)
    -> MoleSegmentationGuidanceStep
  {
    if isProcessing {
      return MoleSegmentationGuidanceStep(
        index: 2,
        total: 3,
        title: "Scanning your image",
        description: "Wait while we detect moles in your photo."
      )
    }
    // If not processing and has detections, prompt user to select mole.
    if hasDetections {
      return MoleSegmentationGuidanceStep(
        index: 3,
        total: 3,
        title: "Find your mole",
        description: "Press and hold directly on the mole area to select it."
      )
    }
    // If not processing, segmentation was attempted but no detections found
    if hasAttemptedSegmentation && !hasDetections {
      return MoleSegmentationGuidanceStep(
        index: 3,
        total: 3,
        title: "No moles detected",
        description: "Try adjusting detection parameters or taking a clearer photo."
      )
    }

    return MoleSegmentationGuidanceStep(
      index: 1,
      total: 3,
      title: "Scan for moles",
      description: "Tap the button to scan this image for detected moles."
    )
  }
}

/// A view that displays a guidance card for mole segmentation, showing different instructions based on the current step in the process.
/// The card adapts its content dynamically as the user progresses through the steps of scanning an image and selecting a detected mole, providing clear instructions at each stage.
/// - Parameters:
///   - step: The current step in the mole segmentation guidance process, containing the index, total steps, title, and description to be displayed on the card.

struct MoleSegmentationGuidanceCard: View {
  let step: MoleSegmentationGuidanceStep

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Text("\(step.index)")
        .font(.subheadline)
        .fontWeight(.bold)
        .frame(width: 28, height: 28)
        .foregroundStyle(.white)
        .background(Circle().fill(Color.blue))

      VStack(alignment: .leading, spacing: 2) {
        Text(step.label)
          .font(.caption)
          .foregroundStyle(.secondary)
        Text(step.title)
          .font(.headline)
          .fontWeight(.semibold)
        Text(step.description)
          .font(.footnote)
          .foregroundStyle(.primary)
          .lineLimit(2)
          .frame(minHeight: 34, alignment: .topLeading)
      }

      Spacer(minLength: 0)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(.ultraThinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 14))
    .overlay(
      RoundedRectangle(cornerRadius: 14)
        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
    )
    .padding(.horizontal, 12)
    .padding(.top, 4)
    .padding(.bottom, 4)
  }
}
