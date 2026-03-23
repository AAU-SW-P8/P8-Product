// 
// OverviewView.swift
// P8-Product
//

import SwiftUI
import SwiftData
import UIKit

public struct OverviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Person.timestamp) private var people: [Person]
    @State private var selectedPerson: Person?
    @State private var showingAddPerson = false
    @State private var newPersonName = ""
    @State private var showingEditPerson = false
    @State private var editingName = ""
    @State private var personToEdit: Person?
    @State private var showingDeleteAlert = false
    @State private var personToDelete: Person?
    @State private var showingDeleteHistoryAlert = false
    @State private var itemToDelete: HistoryItem?
    @State private var slideEdge: Edge = .trailing
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Custom Header
                HStack {
                    Text("Mole Overview")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Spacer()
                    Button(action: {
                        showingAddPerson = true
                    }) {
                        Image(systemName: "person.fill.badge.plus")
                            .font(.system(size: 32))
                            .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal)
                .padding(.top)
                .background(Color(.systemGray6))

                // Top navigation - Person selection tabs
                HStack {
                    Button(action: selectPreviousPerson) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(.primary)
                            .frame(width: 44, height: 44)
                    }
                    .disabled(selectedPerson == people.first)
                    .opacity(selectedPerson == people.first ? 0.3 : 1.0)
                    
                    ZStack {
                        if let person = selectedPerson {
                            Text(person.name)
                                .font(.system(size: 18, weight: .semibold))
                                .lineLimit(1)
                                .foregroundColor(.primary)
                                .contextMenu {
                                    Button {
                                        personToEdit = person
                                        editingName = person.name
                                        showingEditPerson = true
                                    } label: {
                                        Label("Edit Name", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) {
                                        personToDelete = person
                                        showingDeleteAlert = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .background(Color(.systemGray6))
                                .id(person)
                                .transition(.asymmetric(
                                    insertion: .move(edge: slideEdge).combined(with: .opacity),
                                    removal: .move(edge: slideEdge == .leading ? .trailing : .leading).combined(with: .opacity)
                                ))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .clipped()
                    
                    Button(action: selectNextPerson) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(.primary)
                            .frame(width: 44, height: 44)
                    }
                    .disabled(selectedPerson == people.last)
                    .opacity(selectedPerson == people.last ? 0.3 : 1.0)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                
                Divider()
                
                // Mole list
                ZStack {
                    if let person = selectedPerson {
                        List {
                            ForEach(person.historyItems) { item in
                                NavigationLink(destination: Text("Details for \(item.name)")) {
                                    HStack(spacing: 16) {
                                        // Placeholder image
                                        ZStack {
                                            Rectangle()
                                                .fill(Color.gray.opacity(0.2))
                                                .frame(width: 80, height: 80)
                                                .cornerRadius(8)
                                            
                                            Image(systemName: "xmark")
                                                .font(.system(size: 40))
                                                .foregroundColor(.gray.opacity(0.5))
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack {
                                                Text(item.name)
                                                    .font(.system(size: 20, weight: .semibold))
                                                if item.isFlagged {
                                                    Image(systemName: "flag.fill")
                                                        .foregroundColor(.orange)
                                                }
                                            }
                                            Text("Body part")
                                                .font(.system(size: 16))
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                    }
                                    .padding(.vertical, 8)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        itemToDelete = item
                                        showingDeleteHistoryAlert = true
                                    } label: {
                                        Label("Delete", systemImage: "trash.fill")
                                    }
                                    .font(.headline)
                                    .tint(.red)
                                }
                            }
                        }
                        .listStyle(.plain)
                        .id(person)
                        .transition(.asymmetric(
                            insertion: .move(edge: slideEdge),
                            removal: .move(edge: slideEdge == .leading ? .trailing : .leading)
                        ))
                    }
                }
                Spacer()
                // NEW SCAN button
                Button(action: {
                    if let person = selectedPerson {
                        let newItem = HistoryItem(name: "Mole \(person.historyItems.count + 1)", person: person)
                        modelContext.insert(newItem)
                    }
                }) {
                    HStack {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 24))
                        Text("NEW SCAN")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
            }
            .alert("Add Person", isPresented: $showingAddPerson) {
                TextField("Name", text: $newPersonName)
                Button("Add") {
                    if !newPersonName.isEmpty {
                        let person = Person(name: newPersonName)
                        modelContext.insert(person)
                        selectedPerson = person
                        newPersonName = ""
                    }
                }
                Button("Cancel", role: .cancel) {
                    newPersonName = ""
                }
            }
            .alert("Edit Person", isPresented: $showingEditPerson) {
                TextField("Name", text: $editingName)
                Button("Save") {
                    if let person = personToEdit, !editingName.isEmpty {
                        person.name = editingName
                    }
                    personToEdit = nil
                }
                Button("Cancel", role: .cancel) {
                    personToEdit = nil
                }
            }
            .alert("Delete Person", isPresented: $showingDeleteAlert) {
                Button("Delete", role: .destructive) {
                    if let person = personToDelete {
                        deletePerson(person)
                    }
                    personToDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    personToDelete = nil
                }
            } message: {
                Text("Are you sure you want to delete \(personToDelete?.name ?? "this person")?")
            }
            .alert("Delete Item", isPresented: $showingDeleteHistoryAlert) {
                Button("Delete", role: .destructive) {
                    if let item = itemToDelete {
                        modelContext.delete(item)
                    }
                    itemToDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    itemToDelete = nil
                }
            } message: {
                Text("Are you sure you want to delete \(itemToDelete?.name ?? "this item")?")
            }
            .onAppear {
                if people.isEmpty {
                    showingAddPerson = true
                } else if selectedPerson == nil {
                    selectedPerson = people.first
                }
            }
        }
    }
    
    private func selectPreviousPerson() {
        guard let current = selectedPerson, let index = people.firstIndex(of: current), index > 0 else { return }
        slideEdge = .leading
        withAnimation {
            selectedPerson = people[index - 1]
        }
    }
    
    private func selectNextPerson() {
        guard let current = selectedPerson, let index = people.firstIndex(of: current), index < people.count - 1 else { return }
        slideEdge = .trailing
        withAnimation {
            selectedPerson = people[index + 1]
        }
    }
    
    private func deletePerson(_ person: Person) {
        if selectedPerson == person {
            selectedPerson = nil
        }
        modelContext.delete(person)
    }
}
