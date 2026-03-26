// 
// OverviewView.swift
// P8-Product
//

import SwiftUI
import SwiftData
import UIKit

public struct OverviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Person.createdAt) private var people: [Person]
    @State private var selectedPerson: Person?
    @State private var showingAddPerson = false
    @State private var newPersonName = ""
    @State private var showingEditPerson = false
    @State private var editingName = ""
    @State private var personToEdit: Person?
    @State private var showingDeleteAlert = false
    @State private var personToDelete: Person?
    @State private var slideEdge: Edge = .trailing
    @State private var cameraShowing: Bool = false
    @State private var capturedImage: UIImage?
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerView
                personSelectorView
                Divider()
                moleListView
                Spacer()
                newScanButton
            }
            .fullScreenCover(isPresented: $cameraShowing) {
                ARCameraView(capturedImage: $capturedImage)
                    .ignoresSafeArea()
            }
            .onChange(of: capturedImage) { _, newImage in
                guard let image = newImage,
                      let person = selectedPerson else { return }

                let scan = saveMoleScan(image)
                let mole = saveMole(person)
                saveMoleInstance(mole, scan)
                capturedImage = nil
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
            .onAppear {
                // If data is already there on load, select the first person
                if let firstPerson = people.first, selectedPerson == nil {
                    selectedPerson = firstPerson
                }
            }
            // ADD THIS: This watches the database. When MockData finishes
            // inserting, this will trigger and update your UI.
            .onChange(of: people) { _, newValue in
                if selectedPerson == nil, let first = newValue.first {
                    selectedPerson = first
                }
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
    }
    
    private var personSelectorView: some View {
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
    }
    
    private var moleListView: some View {
        ZStack {
            if let person = selectedPerson {
                List {
                    ForEach(person.moles) { mole in
                        NavigationLink(destination: Text("Details for \(mole.name)")) {
                            moleRow(for: mole)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                modelContext.delete(mole)
                                try? modelContext.save()
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
                        Image(systemName: "flag.fill")
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
    
    private var newScanButton: some View {
        Button(action: {
            if selectedPerson != nil {
                cameraShowing = true
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
        try? modelContext.save()
    }
    
    private func saveMoleScan(_ image: UIImage) -> MoleScan {
        let scan = MoleScan(imageData: image.jpegData(compressionQuality: 0.9))
        modelContext.insert(scan)
        return scan
    }
    
    private func saveMole(_ person: Person) -> Mole {
        let mole = Mole(
            name: "Mole \(person.moles.count + 1)",
            bodyPart: "Unassigned",
            isReminderActive: false,
            reminderFrequency: nil,
            nextDueDate: nil,
            person: person
        )
        modelContext.insert(mole)
        return mole
    }
    
    private func saveMoleInstance(_ mole: Mole, _ scan: MoleScan) {
        let instance = MoleInstance(
            diameter: 0,
            area: 0,
            mole: mole,
            moleScan: scan
        )
        modelContext.insert(instance)
    }
    
    
    
    
}
