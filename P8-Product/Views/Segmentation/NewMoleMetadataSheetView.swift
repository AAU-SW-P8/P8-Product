import SwiftUI

/// The `NewMoleMetadataSheetView` type.
struct NewMoleMetadataSheetView: View {
  /// The `showSheet` property.
  @Binding var showSheet: Bool
  /// The `selectedBodyPart` property.
  @Binding var selectedBodyPart: BodyPart
  /// The `newMoleName` property.
  @Binding var newMoleName: String
  /// The `validationMessage` property.
  let validationMessage: String?
  /// The `canSave` property.
  let canSave: Bool
  /// The `onSave` property.
  let onSave: () -> Void

  /// The `body` property.
  var body: some View {
    NavigationStack {
      Form {
        Section("Body Part") {
          Picker("Body Part", selection: $selectedBodyPart) {
            ForEach(BodyPart.allCases) { bodyPart in
              Text(bodyPart.rawValue).tag(bodyPart)
            }
          }
          .pickerStyle(.menu)
          .accessibilityIdentifier("segmentationNewMoleBodyPartPicker")
        }

        Section("Mole Name") {
          TextField("Mole name", text: $newMoleName)
            .accessibilityIdentifier("segmentationNewMoleNameField")
          if let validationMessage {
            Text(validationMessage)
              .font(.caption)
              .foregroundStyle(.red)
          }
          Text("Optional. Leave empty to auto-generate a name.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      .navigationTitle("New Mole")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Cancel") {
            showSheet = false
          }
          .accessibilityIdentifier("segmentationNewMoleCancelButton")
        }
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Save") {
            onSave()
          }
          .disabled(!canSave)
          .accessibilityIdentifier("segmentationNewMoleSaveButton")
        }
      }
    }
  }
}
