import SwiftUI

struct SelectMolePanelView: View {
    let isChoosingAction: Bool
    let personName: String
    let bodyParts: [String]
    @Binding var selectedBodyPart: String?
    let existingMoles: [Mole]
    let moleSubtitle: (Mole) -> String
    let onChooseExisting: () -> Void
    let onChooseNewMole: () -> Void
    let onSelectExistingMole: (Mole) -> Void
    let onCancel: () -> Void

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

    private var panelHeaderCard: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(personName)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)

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
                .tint(.white)
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

    private var panelExistingMoleButton: some View {
        Button {
            onChooseExisting()
        } label: {
            HStack {
                Text("Add to an existing mole")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
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
    }

    private var panelNewMoleButton: some View {
        Button {
            onChooseNewMole()
        } label: {
            HStack {
                Text("Start tracking as a new mole")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))

                Spacer()

                Text("+")
                    .font(.headline)
                    .foregroundStyle(.blue)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .frame(height: 56)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [6]))
                    .foregroundStyle(.white.opacity(0.35))
            )
        }
        .buttonStyle(.plain)
    }

    private var panelCancelButton: some View {
        Button("Cancel") {
            onCancel()
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .padding(.bottom, 16)
    }

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
                        .foregroundStyle(.white)
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
    }
}
