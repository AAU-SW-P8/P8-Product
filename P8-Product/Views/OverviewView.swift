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

private struct OverviewContentView: View {
    // Declared at the top of the struct, so ALL subviews below can see it!
    @Bindable var appState: OverviewAppState
    var people: [Person]
    
    var body: some View {
        navigationContent
            .modifier(OverviewAlertsModifier(appState: appState))
    }

    private var navigationContent: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerView
                personSelectorView
                Divider()
                moleListView
                Spacer()
            }
            .onAppear {
                appState.initializeSelectionIfNeeded(with: people)
            }
            .onChange(of: people) { _, newValue in
                appState.initializeSelectionIfNeeded(with: newValue)
            }
        }
    }

    
    
    // MARK: - Subviews
    
    private var headerView: some View {
        HStack {
            Text("Mole Overview")
                .font(.largeTitle)
                .fontWeight(.bold)
            Spacer()
            Button(action: {
                appState.showingAddPerson = true
            }) {
                Image(systemName: "person.fill.badge.plus")
                    .font(.system(size: 32))
                    .foregroundColor(.primary)
            }
        }
        .padding(.horizontal)
        .padding(.top)
        .background(Color(.systemGray6))
    }
    
    private var personSelectorView: some View {
        HStack {
            Button(action: { appState.selectPreviousPerson(from: people) }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44)
            }
            .disabled(appState.selectedPerson == people.first || people.isEmpty)
            .opacity((appState.selectedPerson == people.first || people.isEmpty) ? 0.3 : 1.0)
            
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
                        .transition(.asymmetric(
                            insertion: .move(edge: appState.slideEdge).combined(with: .opacity),
                            removal: .move(edge: appState.slideEdge == .leading ? .trailing : .leading).combined(with: .opacity)
                        ))
                } else {
                    Text("No Person Selected")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .clipped()
            
            Button(action: { appState.selectNextPerson(from: people) }) {
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
    
    private var moleListView: some View {
        ZStack {
            if let person: Person = appState.selectedPerson {
                List {
                    ForEach(person.moles) { mole in
                        NavigationLink(destination: MoleDetailView(mole: mole)) {
                            moleRow(for: mole)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                appState.requestDelete(mole: mole) // Perfectly in scope here!
                            } label: {
                                Label("Delete", systemImage: "trash.fill")
                            }
                            .tint(.red)
                        }
                    }
                }
                .listStyle(.plain)
                .id(person)
                .transition(.asymmetric(
                    insertion: .move(edge: appState.slideEdge),
                    removal: .move(edge: appState.slideEdge == .leading ? .trailing : .leading)
                ))
            }
        }
    }

    private func moleRow(for mole: Mole) -> some View {
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
                    if mole.isReminderActive {
                        Image(systemName: "bell.fill")
                            .foregroundColor(.orange)
                    }
                }
                Text(mole.bodyPart)
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }

    private func latestScan(for mole: Mole) -> MoleScan? {
        mole.instances
            .compactMap(\.moleScan)
            .sorted { $0.captureDate > $1.captureDate }
            .first
    }
}

private struct OverviewAlertsModifier: ViewModifier {
    @Bindable var appState: OverviewAppState

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
                Button("Delete", role: .destructive) { appState.confirmDeletePerson() }
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
