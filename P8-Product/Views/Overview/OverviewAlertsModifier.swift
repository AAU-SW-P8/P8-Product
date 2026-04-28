///
/// OverviewAlertsModifier.swift
/// P8-Product
///     

import SwiftUI

/// A view modifier that manages the presentation of various alerts in the overview screen.
/// Including adding, editing, and deleting people and moles. 
/// It binds to the OverviewAppState to control the visibility and content of each alert based on user interactions.
struct OverviewAlertsModifier: ViewModifier {
    @Bindable var appState: OverviewAppState
    let people: [Person]
    
    /// Configures the view to present alerts for adding, editing, and deleting people and moles.
    /// With appropriate titles, messages, and actions based on the current state of the app.
    func body(content: Content) -> some View {
        content
            .alert("Add Person", isPresented: $appState.showingAddPerson) {
                TextField("Name", text: $appState.newPersonName)
                Button("Add") { appState.confirmAddPerson() }
                Button("Cancel", role: .cancel) { appState.cancelAddPerson() }
            }
            .alert("Edit Person", isPresented: $appState.showingEditPerson) {
                TextField("Name", text: $appState.editingName)
                Button("Save") { appState.confirmEdit() }
                Button("Cancel", role: .cancel) { appState.cancelEdit() }
            }
            .alert("Delete Person", isPresented: $appState.showingDeleteAlert) {
                Button("Delete", role: .destructive) { appState.confirmDeletePerson(from: people) }
                Button("Cancel", role: .cancel) {
                    appState.personToDelete = nil
                }
            } message: {
                Text(deletePersonMessage)
            }
            .alert("Delete Mole", isPresented: $appState.showingDeleteMoleAlert) {
                Button("Delete", role: .destructive) { appState.confirmDeleteMole() }
                Button("Cancel", role: .cancel) {
                    appState.moleToDelete = nil
                }
            } message: {
                Text(deleteMoleMessage)
            }
    }

    private var deletePersonMessage: String {
        "Are you sure you want to delete \(appState.personToDelete?.name ?? "this person")?"
    }

    private var deleteMoleMessage: String {
        "Are you sure you want to delete \(appState.moleToDelete?.name ?? "this mole")?"
    }
}
