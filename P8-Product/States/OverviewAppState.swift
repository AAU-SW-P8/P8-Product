import SwiftUI
import SwiftData


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
    
    /**
     Initializes the selected person if none is currently selected.
     Should be called when the list of people is loaded or changes.
     */
    func initializeSelectionIfNeeded(with people: [Person]) {
        if selectedPerson == nil, let firstPerson: Person = people.first {
            selectedPerson = firstPerson
        }
    }
    
    /**
     Selects the previous person in the list, if possible, and sets the slide animation direction.
     - Parameter people: The current list of people to determine the index of the selected person.
     */
    func selectPreviousPerson(from people: [Person]) {
        guard let current: Person = selectedPerson,
              let index: Array<Person>.Index = people.firstIndex(of: current),
              index > 0 else { return }
        
        slideEdge = .leading
        withAnimation {
            selectedPerson = people[index - 1]
        }
    }
    
    /**
     Selects the next person in the list, if possible, and sets the slide animation direction.
     - Parameter people: The current list of people to determine the index of the selected person.
     */
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
    
    /** 
     Validates and creates a new person, then selects them and resets the add person state.
     Should be called when confirming the addition of a new person.
     */
    func confirmAddPerson() {
        guard !newPersonName.isEmpty else { return }
        let newPerson: Person = dataController.addPerson(name: newPersonName)
        selectedPerson = newPerson
        newPersonName = ""
        showingAddPerson = false
    }
    
    /**
     Resets the add person state without creating a new person.
     Should be called when cancelling the addition of a new person.
     */
    func cancelAddPerson() {
        newPersonName = ""
        showingAddPerson = false
    }
    
    /**
     Starts the editing process for a person.
     - Parameter person: The person to edit.
     */
    func startEditing(person: Person) {
        personToEdit = person
        editingName = person.name
        showingEditPerson = true
    }
    
    /**
     Validates and saves the edited person's name, then resets the edit state.
     Should be called when confirming the edit of a person.
     */
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
