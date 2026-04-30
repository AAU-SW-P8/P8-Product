///
/// OverviewHeaderView.swift
/// P8-Product
///

import SwiftUI

/// A view representing the header of the overview screen, displaying the title and action buttons for filtering and adding people.
/// - Parameters:
///     - showingFilters: A boolean indicating whether the filter options are currently visible, used to update the accessibility label of the filter button.
///     - onFilterTap: A closure that is called when the filter button is tapped, allowing the parent view to toggle the visibility of the filter options.
///     - onAddPersonTap: A closure that is called when the add person button is tapped,
struct OverviewHeaderView: View {
  // Properties
  let showingFilters: Bool
  let onFilterTap: () -> Void
  let onAddPersonTap: () -> Void

  // MARK: - View Body
  var body: some View {
    HStack {
      Text("Mole Overview")
        .font(.largeTitle)
        .fontWeight(.bold)
      Spacer()
      Button(action: onFilterTap) {
        Image(systemName: "line.3.horizontal.decrease.circle")
          .font(.system(size: 20, weight: .semibold))
          .foregroundColor(.primary)
          .frame(width: 40, height: 40)
      }
      .accessibilityIdentifier("overviewFilterButton")
      .accessibilityLabel(showingFilters ? "Close Filters" : "Open Filters")

      Button(action: onAddPersonTap) {
        Image(systemName: "person.fill.badge.plus")
          .font(.system(size: 20, weight: .semibold))
          .foregroundColor(.primary)
          .frame(width: 40, height: 40)
      }
    }
    .padding(.horizontal)
    .padding(.top)
    .background(Color(.systemGray6))
  }
}
