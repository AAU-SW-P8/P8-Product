///
/// OverviewFilterPopupView.swift
/// P8-Product
///

import SwiftUI

/// A view representing the filter and sort options in the overview screen, allowing users to customize how moles are displayed based on sorting preferences and body part filters.
/// The popup includes a sort picker, a dropdown for selecting body parts to filter by, and buttons to reset filters or confirm selections. It dynamically updates its content based on the available body parts and
/// the user's current selections, providing an intuitive interface for managing the overview display settings.
/// - Parameters:
///   - sortOption: A binding to the current sorting option selected by the user.
///   - selectedBodyParts: A binding to the set of body parts currently selected for filtering.
///   - availableBodyParts: An array of body parts that can be selected for filtering, based on the data available in the app.
///   - onToggleBodyPart: A closure that updates the set of selected body parts when the user selects or deselects a body part.
///   - onReset: A closure that resets all filters to their default values.
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
        Section {
          Picker("Sort By", selection: $sortOption) {
            ForEach(OverviewAppState.MoleSortOption.allCases) { option in
              Text(option.rawValue).tag(option)
            }
          }
          .pickerStyle(.menu)
        } header: {
          Text("Sort By")
        }

        Section {
          VStack(spacing: 0) {
            filterOptionRow(
              title: "All Body Parts",
              isSelected: selectedBodyParts.isEmpty,
              action: { selectedBodyParts = [] }
            )

            ForEach(availableBodyParts, id: \.self) { bodyPart in
              Divider()
                .padding(.leading, 14)

              filterOptionRow(
                title: bodyPart,
                isSelected: selectedBodyParts.contains(bodyPart),
                action: { onToggleBodyPart(bodyPart) }
              )
            }
          }
          .background(Color(.secondarySystemGroupedBackground))
          .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
          .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
              .stroke(Color(.separator).opacity(0.2), lineWidth: 1)
          )
          .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
          .listRowBackground(Color.clear)
          .listRowSeparator(.hidden)
        } header: {
          Text("Filter By")
        } footer: {
          if availableBodyParts.isEmpty {
            Text("No data available to filter.")
          }
        }
      }
      .navigationTitle("Filter & Sort")
      .navigationBarTitleDisplayMode(.inline)
      .listStyle(.insetGrouped)
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

  @ViewBuilder
  private func filterOptionRow(title: String, isSelected: Bool, action: @escaping () -> Void)
    -> some View
  {
    Button(action: action) {
      HStack(spacing: 12) {
        Text(title)
          .foregroundColor(.primary)
          .font(.body.weight(.medium))

        Spacer()

        if isSelected {
          Image(systemName: "checkmark")
            .foregroundColor(.accentColor)
            .font(.system(size: 14, weight: .bold))
        }
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 14)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}
