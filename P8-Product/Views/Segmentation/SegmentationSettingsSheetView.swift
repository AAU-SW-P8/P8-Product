import SwiftUI

/// The `SegmentationSettingsSheetView` type.
struct SegmentationSettingsSheetView: View {
  /// The `showSettings` property.
  @Binding var showSettings: Bool
  /// The `confidenceThreshold` property.
  @Binding var confidenceThreshold: Float
  /// The `nmsThreshold` property.
  @Binding var nmsThreshold: Float

  /// The `body` property.
  var body: some View {
    NavigationStack {
      List {
        Section("Detection Thresholds") {
          VStack(alignment: .leading) {
            HStack {
              Text("Confidence:")
              Spacer()
              Text(String(format: "%.2f", confidenceThreshold))
                .monospacedDigit()
            }
            Slider(value: $confidenceThreshold, in: 0.00...1.00, step: 0.05)
          }

          VStack(alignment: .leading) {
            HStack {
              Text("NMS Overlap:")
              Spacer()
              Text(String(format: "%.2f", nmsThreshold))
                .monospacedDigit()
            }
            Slider(value: $nmsThreshold, in: 0.00...1.00, step: 0.05)
            Text("Higher values allow more overlapping boxes.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      }
      .navigationTitle("Parameters")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Done") {
            showSettings = false
          }
        }
      }
      .presentationDetents([.height(300)])
    }
  }
}
