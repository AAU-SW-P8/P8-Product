import SwiftUI

/// The `SelectMolePanelView` type.
struct SelectMolePanelView: View {
  /// The `isChoosingAction` property.
  let isChoosingAction: Bool
  /// The `personName` property.
  let personName: String
  /// The `bodyParts` property.
  let bodyParts: [String]
  /// The `selectedBodyPart` property.
  @Binding var selectedBodyPart: String?
  /// The `existingMoles` property.
  let existingMoles: [Mole]
  /// The `moleSubtitle` property.
  let moleSubtitle: (Mole) -> String
  /// The `onChooseExisting` property.
  let onChooseExisting: () -> Void
  /// The `onChooseNewMole` property.
  let onChooseNewMole: () -> Void
  /// The `onSelectExistingMole` property.
  let onSelectExistingMole: (Mole) -> Void
  /// The `onCancel` property.
  let onCancel: () -> Void

  /// The `body` property.
  var body: some View {
    VStack(spacing: 14) {
      if isChoosingAction {
        panelActionChooser
      } else {
        panelExistingSection
        panelCancelButton
      }
    }
    .padding(.top, 14)
    .padding(.bottom, 12)
    .background(
      RoundedRectangle(cornerRadius: 22, style: .continuous)
        .fill(Color(.systemGray6).opacity(0.96))
        .overlay {
          RoundedRectangle(cornerRadius: 22, style: .continuous)
            .stroke(.white.opacity(0.08), lineWidth: 1)
        }
    )
    .frame(height: 520, alignment: .top)
    .padding(.horizontal, 12)
    .ignoresSafeArea(edges: .bottom)
  }

  /// The `panelActionChooser` property.
  private var panelActionChooser: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("CHOOSE AN ACTION")
        .font(.caption2)
        .fontWeight(.semibold)
        .foregroundStyle(.secondary)

      panelExistingMoleButton
      panelOrDivider
      panelNewMoleButton
    }
    .padding(.horizontal, 16)
    .padding(.top, 4)
    .padding(.bottom, 4)
  }

  /// The `panelExistingSection` property.
  private var panelExistingSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      panelHeaderCard

      Rectangle()
        .fill(.white.opacity(0.14))
        .frame(height: 1)
        .frame(maxWidth: .infinity)

      Text("ADD TO AN EXISTING MOLE RECORD")
        .font(.caption2)
        .fontWeight(.semibold)
        .foregroundStyle(.secondary)

      panelMoleRows
    }
    .padding(.horizontal, 18)
    .padding(.top, 8)
    .padding(.bottom, 6)
  }

  /// The `panelHeaderCard` property.
  private var panelHeaderCard: some View {
    HStack(alignment: .center, spacing: 10) {
      Text(personName)
        .font(.headline)
        .fontWeight(.semibold)

      Spacer(minLength: 8)

      HStack(alignment: .center, spacing: 6) {
        Text("Body part")
          .font(.caption2)
          .foregroundStyle(.secondary)

        Picker("Body Part", selection: $selectedBodyPart) {
          Text("All").tag(Optional<String>.none)
          ForEach(bodyParts, id: \.self) { bodyPart in
            Text(bodyPart).tag(Optional(bodyPart))
          }
        }
        .labelsHidden()
        .font(.subheadline)
      }
      .pickerStyle(.menu)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .fill(.black.opacity(0.25))
    )
  }

  /// The `panelMoleRows` property.
  @ViewBuilder
  private var panelMoleRows: some View {
    if existingMoles.isEmpty {
      Text("No existing moles for this selection.")
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.vertical, 6)
    } else {
      ScrollView {
        LazyVStack(spacing: 8) {
          ForEach(existingMoles) { mole in
            existingMoleRow(mole: mole)
          }
        }
      }
      .frame(maxHeight: 220)
    }
  }

  /// The `panelOrDivider` property.
  private var panelOrDivider: some View {
    HStack(spacing: 12) {
      Rectangle().fill(.white.opacity(0.12)).frame(height: 1)
      Text("or")
        .font(.caption)
        .foregroundStyle(.secondary)
      Rectangle().fill(.white.opacity(0.12)).frame(height: 1)
    }
    .padding(.horizontal, 16)
  }

  /// The `panelExistingMoleButton` property.
  private var panelExistingMoleButton: some View {
    Button {
      onChooseExisting()
    } label: {
      HStack {
        Text("Add to an existing mole")
          .font(.subheadline)
          .fontWeight(.semibold)
        Spacer()
        Text("→")
          .font(.headline)
          .foregroundStyle(.blue)
      }
      .frame(maxWidth: .infinity)
      .padding(.horizontal, 12)
      .frame(height: 56)
      .background(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .fill(.black.opacity(0.3))
      )
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier("segmentationChooseExistingMoleButton")
  }

  /// The `panelNewMoleButton` property.
  private var panelNewMoleButton: some View {
    Button {
      onChooseNewMole()
    } label: {
      HStack {
        Text("Start tracking as a new mole")
          .font(.subheadline)

        Spacer()

        Text("+")
          .font(.headline)
          .foregroundStyle(.blue)
      }
      .frame(maxWidth: .infinity)
      .padding(.horizontal, 12)
      .frame(height: 56)
      .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .stroke(
            style: StrokeStyle(lineWidth: 1, dash: [6])
          )
      )
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier("segmentationChooseNewMoleButton")
  }

  /// The `panelCancelButton` property.
  private var panelCancelButton: some View {
    Button("Cancel") {
      onCancel()
    }
    .font(.footnote)
    .foregroundStyle(.secondary)
    .padding(.bottom, 16)
    .accessibilityIdentifier("segmentationSelectMoleCancelButton")
  }

  /// The `existingMoleRow` function.
  @ViewBuilder
  private func existingMoleRow(mole: Mole) -> some View {
    Button {
      onSelectExistingMole(mole)
    } label: {
      HStack(spacing: 12) {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .fill(.black.opacity(0.4))
          .frame(width: 34, height: 34)
          .overlay {
            Circle()
              .fill(.white.opacity(0.8))
              .frame(width: 8, height: 8)
          }

        VStack(alignment: .leading, spacing: 4) {
          Text(mole.name)
            .font(.subheadline)
            .fontWeight(.semibold)
          Text(moleSubtitle(mole))
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }

        Spacer(minLength: 12)

        Text("Add →")
          .font(.subheadline)
          .fontWeight(.semibold)
          .foregroundStyle(.blue)
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 10)
      .background(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .fill(.black.opacity(0.3))
      )
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier("segmentationExistingMoleRow_\(mole.name)")
  }
}
