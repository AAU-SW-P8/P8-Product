import SwiftUI
import SwiftData
import UIKit

@MainActor
@Observable
class OverviewAppState {
    // MARK: - Persistent Data Selection
    var selectedPerson: Person?
    
    // MARK: - UI Flow State
    var showingAddPerson: Bool = false
    var showingEditPerson: Bool = false
    var showingDeleteAlert: Bool = false
    var showingDeleteMoleAlert: Bool = false
    var cameraShowing: Bool = false
    
    // MARK: - UI Animation State
    var slideEdge: Edge = .trailing
    
    // MARK: - Temporary Data State
    var newPersonName: String = ""
    var editingName: String = ""
    var personToEdit: Person?
    var personToDelete: Person?
    var moleToDelete: Mole?
    var capturedImage: UIImage?
    
    private let dataController: DataController
    
    init(dataController: DataController) {
        self.dataController = dataController
    }
    
    // MARK: - Person Initialization & Navigation
    
    func initializeSelectionIfNeeded(with people: [Person]) {
        if selectedPerson == nil, let firstPerson: Person = people.first {
            selectedPerson = firstPerson
        }
    }
    
    func selectPreviousPerson(from people: [Person]) {
        guard let current: Person = selectedPerson,
              let index: Array<Person>.Index = people.firstIndex(of: current),
              index > 0 else { return }
        
        slideEdge = .leading
        withAnimation {
            selectedPerson = people[index - 1]
        }
    }
    
    func selectNextPerson(from people: [Person]) {
        guard let current: Person = selectedPerson,
              let index: Array<Person>.Index = people.firstIndex(of: current),
              index < people.count - 1 else { return }
        
        slideEdge = .trailing
        withAnimation {
            selectedPerson = people[index + 1]
        }
    }
    
    // MARK: - Person CRUD Actions
    
    func confirmAddPerson() {
        guard !newPersonName.isEmpty else { return }
        let newPerson: Person = dataController.addPerson(name: newPersonName)
        selectedPerson = newPerson
        newPersonName = ""
        showingAddPerson = false
    }
    
    func cancelAddPerson() {
        newPersonName = ""
        showingAddPerson = false
    }
    
    func startEditing(person: Person) {
        personToEdit = person
        editingName = person.name
        showingEditPerson = true
    }
    
    func confirmEdit() {
        if let person: Person = personToEdit, !editingName.isEmpty {
            person.name = editingName // Updates the SwiftData Model
        }
        cancelEdit()
    }
    
    func cancelEdit() {
        personToEdit = nil
        editingName = ""
        showingEditPerson = false
    }
    
    func requestDelete(person: Person) {
        personToDelete = person
        showingDeleteAlert = true
    }

    func confirmDeletePerson() {

        defer {
            personToDelete = nil
            showingDeleteAlert = false
        }

        guard let person: Person = personToDelete else { return }

        if selectedPerson == person { 
            selectedPerson = nil 
        }

        dataController.delete(person)

    }
    
    // MARK: - Mole Actions
    
    func requestDelete(mole: Mole) {
        moleToDelete = mole
        showingDeleteMoleAlert = true
    }
    
    func confirmDeleteMole() {

        defer {
            moleToDelete = nil
            showingDeleteMoleAlert = false
        }

        guard let mole: Mole = moleToDelete else { return}

        dataController.delete(mole)
        
    }
    
    // MARK: - Camera & Scan Actions
    
    func processCapturedImage() {
        guard let image: UIImage = capturedImage, let person: Person = selectedPerson else { return }
        
        dataController.addMoleAndScan(to: person, image: image)
        
        // Clean up
        self.capturedImage = nil
    }
}
