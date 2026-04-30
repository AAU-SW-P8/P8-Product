///
/// OverviewPersonSelectorView.swift
/// P8-Product
///

import SwiftUI

/// A view that allows users to select a person from the overview screen, displaying the selected person's name and providing navigation buttons to switch between people.
/// - Parameters:
///   - appState: A binding to the OverviewAppState, which manages the selected person
///   - people: An array of Person objects representing the available people to select from. The view updates its content based on the currently selected person and provides context menu options for editing or deleting the selected person.
struct OverviewPersonSelectorView: View {
  // Properties
  @Bindable var appState: OverviewAppState
  let people: [Person]

  // MARK: - View Body
  var body: some View {
    HStack {
      Button {
        appState.selectPreviousPerson(from: people)
      } label: {
        Image(systemName: "chevron.left")
          .font(.system(size: 30, weight: .bold))
          .foregroundColor(.primary)
          .frame(width: 44, height: 44)
      }
      .disabled(appState.selectedPerson == people.first || people.isEmpty)
      .opacity((appState.selectedPerson == people.first || people.isEmpty) ? 0.3 : 1.0)

      // Display the name of the currently selected person, or a placeholder if no person is selected.
      // The name is displayed with a context menu that allows editing or deleting the person.
      ZStack {
        if let person = appState.selectedPerson {
          Text(person.name)
            .font(.system(size: 18, weight: .semibold))
            .lineLimit(1)
            .foregroundColor(.primary)
            .contextMenu {
              Button {
                appState.startEditing(person: person)
              } label: {
                Label("Edit Name", systemImage: "pencil")
              }
              Button(role: .destructive) {
                appState.requestDelete(person: person)
              } label: {
                Label("Delete", systemImage: "trash")
              }
            }
            .background(Color(.systemGray6))
            .id(person)
            .transition(
              .asymmetric(
                insertion: .move(edge: appState.slideEdge).combined(with: .opacity),
                removal: .move(edge: appState.slideEdge == .leading ? .trailing : .leading)
                  .combined(with: .opacity)
              ))
        } else {
          Text("No Person Registered")
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(.secondary)
        }
      }
      .frame(maxWidth: .infinity)
      .clipped()

      Button {
        appState.selectNextPerson(from: people)
      } label: {
        Image(systemName: "chevron.right")
          .font(.system(size: 30, weight: .bold))
          .foregroundColor(.primary)
          .frame(width: 44, height: 44)
      }
      .disabled(appState.selectedPerson == people.last || people.isEmpty)
      .opacity((appState.selectedPerson == people.last || people.isEmpty) ? 0.3 : 1.0)
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 8)
    .background(Color(.systemGray6))
  }
}
