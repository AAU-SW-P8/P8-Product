// 
// OverviewView.swift
// P8-Product
//

import SwiftUI
import SwiftData
import UIKit

/**
 The `OverviewView` is the main interface for displaying and managing people, their moles, and associated scans. It provides navigation between people, a list of their moles, and actions to add/edit/delete people and moles. The view relies on `OverviewAppState` for managing its state and interactions with the data layer.
 */
public struct OverviewView: View {
    @Query(sort: \Person.createdAt) private var people: [Person]
    
    @State private var appState = OverviewAppState(dataController: .shared)
    
    public init() {}
    
    public var body: some View {
        OverviewContentView(appState: appState, people: people)
    }
}

/// A private subview that contains the main content of the OverviewView, including the header, person selector, mole list, and filter popup. This struct is defined separately to keep the main OverviewView clean and focused on data fetching and state management.
/// - Parameters:
///   - appState: The state object that manages the UI state and interactions for the overview
///   - people: The list of people fetched from the data store, which is passed down to child views for display and interaction.
private struct OverviewContentView: View {
    // Constants for layout and sizing
    private let bodyPartRowHeight: CGFloat = 34
    private let bodyPartMaxVisibleRows: CGFloat = 5

    // Declared at the top of the struct, so ALL subviews below can see it!
    @Bindable var appState: OverviewAppState
    var people: [Person]

    // State for filter popup, lifted up to this level so it can be shared between the header and the popup view.
    @State private var selectedBodyParts: Set<String> = []
    @State private var sortOption: OverviewAppState.MoleSortOption = .recent
    @State private var showingFilters: Bool = false
    @State private var showingBodyPartDropdown: Bool = false
    
    // MARK: - View Body
    var body: some View {
        navigationContent
            .modifier(OverviewAlertsModifier(appState: appState, people: people))
            .onAppear {
                appState.initializeSelectionIfNeeded(with: people)
            }
            .onChange(of: people) { _, newValue in
                appState.initializeSelectionIfNeeded(with: newValue)
            }
    }

    // MARK: - Subviews

    /// Header and navigation content, including the header with filter and add person buttons, the person selector with navigation between people, and the list of moles for the selected person. Also manages the presentation of the filter popup and its interaction with the rest of the UI.
    private var navigationContent: some View {
    NavigationStack {
        VStack(spacing: 0) {
            OverviewHeaderView(
                showingFilters: showingFilters,
                onFilterTap: { showingFilters = true }, // Simply trigger the sheet
                onAddPersonTap: { appState.showingAddPerson = true }
            )
            
            OverviewPersonSelectorView(appState: appState, people: people)
            
            Divider()
            
            if let person = appState.selectedPerson {
                OverviewMoleListView(
                    appState: appState,
                    person: person,
                    moles: displayedMoles(for: person)
                )
            }
            Spacer()
        }
        // RESET LOGIC: Reset filters to "All" when switching person
        .onChange(of: appState.selectedPerson?.id) { _, _ in
            selectedBodyParts = [] 
            sortOption = .recent
        }
        // NATIVE FILTER SHEET
        .sheet(isPresented: $showingFilters) {
            OverviewFilterPopupView(
                sortOption: $sortOption,
                selectedBodyParts: $selectedBodyParts,
                availableBodyParts: availableBodyParts,
                onToggleBodyPart: toggleBodyPart,
                onReset: {
                    selectedBodyParts = []
                    sortOption = .recent
                }
            )
            .presentationDetents([.medium, .large]) // Standard iOS detents
            .presentationDragIndicator(.visible)
        }
    }
    }

    private func toggleBodyPart(_ bodyPart: String) {
        if selectedBodyParts.contains(bodyPart) {
            selectedBodyParts.remove(bodyPart)
        } else {
            selectedBodyParts.insert(bodyPart)
        }
        
        // "ALL" LOGIC: If all parts are selected, reset to "All" (empty set)
        if !availableBodyParts.isEmpty && selectedBodyParts.count == availableBodyParts.count {
            selectedBodyParts = []
        }
    }

    // MARK: - Helper Functions

    /// Opens the filter popup with an animation, setting the `showingFilters` state to true. This function is called when the user taps the filter button in the header, and it triggers the display of the `OverviewFilterPopupView`.
    private func openFilterPopup() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
            showingFilters = true
        }
    }

    /// Closes the filter popup with an animation, setting the `showingFilters` and `showingBodyPartDropdown` states to false. This function is called when the user taps outside the popup or confirms their filter selections, and it triggers the hiding of the `OverviewFilterPopupView`.
    private func closeFilterPopup() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
            showingBodyPartDropdown = false
            showingFilters = false
        }
    }

    /// Computes a summary string of the currently selected body parts for filtering, which is displayed on the body part dropdown button when the dropdown is not expanded. If no body parts are selected, it returns "All body parts". Otherwise, it returns a comma-separated list of the selected body parts, sorted alphabetically.
    private var selectedBodyPartsSummary: String {
        if selectedBodyParts.isEmpty {
            return "All body parts"
        }

        return selectedBodyParts
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            .joined(separator: ", ")
    }

    /// Computes the height of the body part dropdown based on the number of available body parts and a maximum visible row count. If there are no available body parts, it returns a minimum height to show an empty state. Otherwise, it calculates the height as the number of body parts (up to the maximum) multiplied by the row height.
    private var bodyPartDropdownHeight: CGFloat {
        let rowCount = min(CGFloat(availableBodyParts.count), bodyPartMaxVisibleRows)
        let minRows: CGFloat = availableBodyParts.isEmpty ? 1 : rowCount
        return max(bodyPartRowHeight, minRows * bodyPartRowHeight)
    }

    /// Computes the list of available body parts for filtering based on the currently selected person. It retrieves the selected person from the app state and returns a sorted list of unique body parts from that person's moles. If no person is selected, it returns an empty array.
    private var availableBodyParts: [String] {
        guard let person = appState.selectedPerson else { return [] }
        return appState.availableBodyParts(for: person)
    }

    /// Computes the list of moles to display for the selected person, based on the current filter and sort options. It retrieves the selected person from the app state and calls the `displayedMoles` function in the app state, passing in the selected body parts and sort option. If no person is selected, it returns an empty array.
    private func displayedMoles(for person: Person) -> [Mole] {
        appState.displayedMoles(
            for: person,
            selectedBodyParts: selectedBodyParts,
            sortOption: sortOption
        )
    }
}
