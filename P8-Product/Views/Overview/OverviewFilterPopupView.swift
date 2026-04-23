///
/// OverviewFilterPopupView.swift
/// P8-Product
///     

import SwiftUI

/// A view representing the filter and sort options in the overview screen, allowing users to customize how moles are displayed based on sorting preferences and body part filters.
/// The popup includes a sort picker, a dropdown for selecting body parts to filter by, and buttons to reset filters or confirm selections. It dynamically updates its content based on the available body parts and
/// the user's current selections, providing an intuitive interface for managing the overview display settings.
/// - Parameters:
///     - sortOption: A binding to the current sorting option selected by the user.
///     - showingBodyPartDropdown: A binding that controls the visibility of the body part selection dropdown.
///     - selectedBodyParts: A binding to the set of body parts currently selected for filtering.
///     - availableBodyParts: An array of body parts that can be selected for filtering, based on the data available in the app.
///     - selectedBodyPartsSummary: A string summarizing the currently selected body parts, displayed on
///     - body part dropdown button when the dropdown is not expanded.
///     - onToggleBodyPartDropdown: A closure that toggles the visibility of the body part dropdown when the user taps the corresponding button.
///     - onToggleBodyPart: A closure that updates the set of selected body parts when the user selects or deselects a body part.
///     - onReset: A closure that resets all filters to their default values.
///     - onDone: A closure that confirms the current filter selections and closes the popup.
struct OverviewFilterPopupView: View {
    // Bindings to parent view state
    @Binding var sortOption: OverviewAppState.MoleSortOption
    @Binding var showingBodyPartDropdown: Bool
    @Binding var selectedBodyParts: Set<String>

    let availableBodyParts: [String]
    let selectedBodyPartsSummary: String
    let bodyPartDropdownHeight: CGFloat

    let onToggleBodyPartDropdown: () -> Void
    let onToggleBodyPart: (String) -> Void
    let onReset: () -> Void
    let onDone: () -> Void

    // MARK: - View Body
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Filter & Sort")
                    .font(.headline)
                    .accessibilityIdentifier("overviewFilterPopupTitle")
                Spacer()
                Picker("Sort", selection: $sortOption) {
                    ForEach(OverviewAppState.MoleSortOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 110)
                .accessibilityIdentifier("overviewSortPicker")
                .accessibilityLabel("Sort Picker")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Body Parts")
                    .font(.subheadline.weight(.semibold))

                Button(action: onToggleBodyPartDropdown) {
                    HStack {
                        Text(selectedBodyPartsSummary)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: showingBodyPartDropdown ? "chevron.up" : "chevron.down")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("overviewBodyPartDropdownButton")
                .accessibilityLabel("Body Part Filter")

                if showingBodyPartDropdown {
                    VStack(alignment: .leading, spacing: 6) {
                        if availableBodyParts.isEmpty {
                            Text("No body parts available")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            HStack {
                                Button("Select All") {
                                    selectedBodyParts = Set(availableBodyParts)
                                }
                                .buttonStyle(.plain)
                                .font(.subheadline)
                                .accessibilityIdentifier("overviewBodyPartSelectAllButton")

                                Spacer()

                                Button("Clear") {
                                    selectedBodyParts = []
                                }
                                .buttonStyle(.plain)
                                .font(.subheadline)
                                .accessibilityIdentifier("overviewBodyPartClearButton")
                            }
                            .foregroundColor(.secondary)

                            ScrollView {
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(availableBodyParts, id: \.self) { bodyPart in
                                        Button {
                                            onToggleBodyPart(bodyPart)
                                        } label: {
                                            HStack(spacing: 8) {
                                                Image(systemName: selectedBodyParts.contains(bodyPart) ? "checkmark.circle.fill" : "circle")
                                                    .foregroundColor(selectedBodyParts.contains(bodyPart) ? .accentColor : .secondary)
                                                Text(bodyPart)
                                                    .foregroundColor(.primary)
                                                Spacer()
                                            }
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 6)
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityIdentifier("overviewBodyPartOption_\(bodyPart.replacingOccurrences(of: " ", with: "_"))")
                                    }
                                }
                            }
                            .frame(height: bodyPartDropdownHeight)
                        }
                    }
                    .padding(10)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .accessibilityIdentifier("overviewBodyPartDropdownList")
                }
            }

            HStack {
                Button("Reset", action: onReset)
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier("overviewFilterResetButton")

                Spacer()

                Button("Done", action: onDone)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("overviewFilterDoneButton")
            }

            Text("Filter Popup Visible")
                .font(.caption2)
                .foregroundColor(.clear)
                .accessibilityIdentifier("overviewFilterPopupVisibleMarker")
        }
        .padding()
        .frame(width: 320)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
        .accessibilityIdentifier("overviewFilterPopup")
    }
}
