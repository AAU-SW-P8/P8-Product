import SwiftUI
import SwiftData
import UIKit
import CoreVideo
import simd

@MainActor
@Observable
class OverviewAppState {
    enum MoleSortOption: String, CaseIterable, Identifiable {
        case recent = "Recent"
        case alphabetical = "A-Z"
        case nextDueDate = "Next Due Date"

        var id: String { rawValue }
    }

    // The selected person is shared across the app through SelectionState, so that all views stay in sync without needing to pass the selection through the view hierarchy.
    @ObservationIgnored private let selectionState = SelectionState.shared

    // MARK: - Persistent Data Selection
    var selectedPerson: Person? {
        get { selectionState.selectedPerson }
        set { selectionState.selectedPerson = newValue }
    }

    var selectedMole: Mole? {
        get { selectionState.selectedMole }
        set { selectionState.selectedMole = newValue }
    }

    // Keeps list-driven navigation stable while detail view is open.
    var selectedMoleNavigationID: UUID?
    
    // MARK: - UI Flow State
    var showingAddPerson: Bool = false
    var showingEditPerson: Bool = false
    var showingDeleteAlert: Bool = false
    var showingDeleteMoleAlert: Bool = false

    // MARK: - UI Animation State
    var slideEdge: Edge = .trailing

    // MARK: - Temporary Data State
    var newPersonName: String = ""
    var editingName: String = ""
    var personToEdit: Person?
    var personToDelete: Person?
    var moleToDelete: Mole?
    var capturedImage: UIImage?
    var capturedDepthMap: CVPixelBuffer?
    var capturedConfidenceMap: CVPixelBuffer?
    var capturedIntrinsics: simd_float3x3?
    
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
            dataController.rename(person, to: editingName)
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

    func selectMole(_ mole: Mole?) {
        selectedMole = mole
        selectedMoleNavigationID = mole?.id
    }
    
    func confirmDeleteMole() {

        defer {
            moleToDelete = nil
            showingDeleteMoleAlert = false
        }

        guard let mole: Mole = moleToDelete else { return}

        dataController.delete(mole)
        
    }

    // MARK: - Overview Filtering & Sorting

    func availableBodyParts(for person: Person) -> [String] {
        Array(Set(person.moles.map(\.bodyPart)))
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    func displayedMoles(
        for person: Person,
        selectedBodyParts: Set<String>,
        sortOption: MoleSortOption
    ) -> [Mole] {
        let filtered: [Mole] = person.moles.filter { mole in
            selectedBodyParts.isEmpty || selectedBodyParts.contains(mole.bodyPart)
        }

        switch sortOption {
        case .alphabetical:
            return filtered.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        case .nextDueDate:
            return filtered.sorted { lhs, rhs in
                let lhsDate = lhs.nextDueDate ?? .distantFuture
                let rhsDate = rhs.nextDueDate ?? .distantFuture

                if lhsDate != rhsDate {
                    return lhsDate < rhsDate
                }

                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        case .recent:
            return filtered.sorted {
                let lhsDate = latestScan(for: $0)?.captureDate ?? .distantPast
                let rhsDate = latestScan(for: $1)?.captureDate ?? .distantPast
                return lhsDate > rhsDate
            }
        }
    }

    func latestScan(for mole: Mole) -> MoleScan? {
        mole.instances
            .compactMap(\.moleScan)
            .sorted { $0.captureDate > $1.captureDate }
            .first
    }

}
