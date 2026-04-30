///
/// OverviewMoleListView.swift
/// P8-Product
///

import SwiftUI

/// A view that displays a list of moles for a selected person in the overview screen. Each mole is shown with its name, body part, and a thumbnail image from the latest scan. The view also indicates if a reminder is active for each mole and allows navigation to the mole's detail view. Swipe actions are provided for deleting moles, with confirmation alerts managed by the parent view state.
/// - Parameters:
///   - appState: A binding to the OverviewAppState, which manages the selected mole
///   - person: The Person object whose moles are being displayed.
///   - moles: An array of Mole objects representing the moles associated with the selected person
struct OverviewMoleListView: View {
  // Properties
  @Bindable var appState: OverviewAppState
  let person: Person
  let moles: [Mole]

  // MARK: - View Body
  var body: some View {
    List {
      ForEach(moles, id: \.id) { mole in
        NavigationLink(
          destination: MoleDetailView(mole: mole),
          tag: mole.id,
          selection: selectedMoleIDBinding(for: person)
        ) {
          moleRow(for: mole, person: person)
        }
        .accessibilityIdentifier("overviewMoleRow_\(mole.name)")
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
          Button {
            appState.requestDelete(mole: mole)
          } label: {
            Label("Delete", systemImage: "trash.fill")
          }
          .accessibilityIdentifier("overviewDeleteMoleButton_\(mole.name)")
          .tint(.red)
        }
      }
    }
    .listStyle(.plain)
    .id(person.id)
    .transition(
      .asymmetric(
        insertion: .move(edge: appState.slideEdge),
        removal: .move(edge: appState.slideEdge == .leading ? .trailing : .leading)
      ))
  }

  // MARK: - Subviews and Helpers
  /// Creates a binding for the selected mole's ID, allowing the NavigationLink to update the selected mole in the app state when a mole is tapped. This binding checks the current selected mole ID against the IDs of the moles for the selected person and updates the selection accordingly.
  private func selectedMoleIDBinding(for person: Person) -> Binding<UUID?> {
    Binding(
      get: { appState.selectedMoleNavigationID },
      set: { newID in
        let selected = person.moles.first { $0.id == newID }
        appState.selectMole(selected)
      }
    )
  }

  /// Creates a view for a single mole row in the list, displaying the mole's name, body part, and a thumbnail image from the latest scan. It also checks if a reminder is active for the mole and shows a bell icon if so. The row is designed to be tappable, allowing navigation to the mole's detail view when selected.
  /// - Parameters:
  ///   - mole: The Mole object representing the mole to be displayed in the row.
  ///   - person: The Person object associated with the mole, used to determine if the reminder is active based on the person's default reminder settings.
  /// - Returns: A view representing a single row in the mole list, showing the mole's details and reminder status.
  private func moleRow(for mole: Mole, person: Person) -> some View {
    HStack(spacing: 16) {
      ZStack {
        Rectangle()
          .fill(Color.gray.opacity(0.2))
          .frame(width: 80, height: 80)
          .cornerRadius(8)

        if let data = latestScan(for: mole)?.imageData, let uiImage = UIImage(data: data) {
          Image(uiImage: uiImage)
            .resizable()
            .scaledToFill()
            .frame(width: 80, height: 80)
            .cornerRadius(8)
        } else {
          Image(systemName: "photo")
            .font(.system(size: 40))
            .foregroundColor(.gray.opacity(0.5))
        }
      }

      VStack(alignment: .leading, spacing: 4) {
        HStack {
          Text(mole.name)
            .font(.system(size: 20, weight: .semibold))
          if effectiveReminderEnabled(for: mole, person: person) {
            Image(systemName: "bell.fill")
              .foregroundColor(.orange)
              .accessibilityIdentifier("overviewReminderIcon_\(mole.name)")
          }
        }
        Text(mole.bodyPart)
          .font(.system(size: 16))
          .foregroundColor(.secondary)
      }

      Spacer()
    }
    .contentShape(Rectangle())
    .padding(.vertical, 8)
  }

  /// Determines if a reminder is active for a given mole, taking into account both the mole's individual reminder setting and the person's default reminder setting. If the mole is set to follow the default reminder, it checks the person's default reminder status; otherwise, it checks the mole's specific reminder status. This allows for flexible reminder management where moles can either inherit the person's default setting or have their own independent reminder status.
  /// - Parameters:
  ///   - mole: The Mole object for which to determine the reminder status.
  ///   - person: The Person object associated with the mole, used to check the default reminder setting if the mole is set to follow the default.
  /// - Returns: A Boolean value indicating whether a reminder is active for the mole, based on the combined logic of the mole's settings
  private func effectiveReminderEnabled(for mole: Mole, person: Person) -> Bool {
    if mole.followDefaultReminderEnabled ?? true {
      return person.defaultReminderEnabled
    }
    return mole.isReminderActive
  }

  /// Retrieves the latest scan for a given mole by accessing the app state. This function checks the app state for the most recent scan associated with the mole, allowing the view to display the most up-to-date thumbnail image for each mole in the list. If no scans are available, it returns nil, and a placeholder image is shown instead.
  /// - Parameter
  ///   - mole: The Mole object for which to retrieve the latest scan.
  /// - Returns: An optional MoleScan object representing the latest scan for the mole, or
  private func latestScan(for mole: Mole) -> MoleScan? {
    appState.latestScan(for: mole)
  }
}
