import SwiftUI

/// The `MoleSegmentationBottomActionAreaView` type.
struct MoleSegmentationBottomActionAreaView: View {
  /// The `isProcessing` property.
  let isProcessing: Bool
  /// The `primaryButtonTitle` property.
  let primaryButtonTitle: String
  /// The `onPrimaryAction` property.
  let onPrimaryAction: () -> Void

  /// The `body` property.
  var body: some View {
    VStack(spacing: 8) {
      Button {
        onPrimaryAction()
      } label: {
        HStack(spacing: 10) {
          if isProcessing {
            ProgressView()
              .tint(.white)
          }

          Text(primaryButtonTitle)
            .font(.title3)
            .fontWeight(.semibold)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .background(Color.blue)
        .clipShape(Capsule())
      }
      .buttonStyle(.plain)
      .disabled(isProcessing)
      .accessibilityIdentifier("moleSegmentationPrimaryActionButton")

      Text("Your photos never leave your device")
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 16)
    .padding(.top, 10)
    .padding(.bottom, 8)
    .background(.ultraThinMaterial)
    .accessibilityIdentifier("moleSegmentationBottomActionArea")
  }
}
