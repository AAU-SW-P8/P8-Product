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
    @Binding var sortOption: OverviewAppState.MoleSortOption
    @Binding var selectedBodyParts: Set<String>
    
    let availableBodyParts: [String]
    let onToggleBodyPart: (String) -> Void
    let onReset: () -> Void
    
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Sort Order") {
                    Picker("Sort By", selection: $sortOption) {
                        ForEach(OverviewAppState.MoleSortOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.menu) // The "Bubble" style you like
                }
                
                ScrollView(.vertical, showsIndicators: false) {
                Section {
                    // "All" Row
                    Button(action: { selectedBodyParts = [] }) {
                        HStack {
                            Text("All Body Parts")
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedBodyParts.isEmpty {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                                    .font(.system(size: 14, weight: .bold))
                            }
                        }
                    }
                    
                    // Specific Body Parts
                    ForEach(availableBodyParts, id: \.self) { bodyPart in
                        Button(action: { onToggleBodyPart(bodyPart) }) {
                            HStack {
                                Text(bodyPart)
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedBodyParts.contains(bodyPart) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                        .font(.system(size: 14, weight: .bold))
                                }
                            }
                        }
                    }
                } header: {
                    Text("Filter by Body Part")
                } footer: {
                    if availableBodyParts.isEmpty {
                        Text("No data available to filter.")
                    }
                }
            }
            .navigationTitle("Filter & Sort")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Reset", action: onReset)
                        .foregroundColor(.red)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.bold)
                }
            }
            }
        }
    }
}

