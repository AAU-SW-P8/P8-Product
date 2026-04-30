import CoreVideo
import SwiftData
import SwiftUI
import UIKit
import simd

/// Overview app state.
@MainActor
@Observable
class OverviewAppState {
  enum MoleSortOption: String, CaseIterable, Identifiable {
    case recent = "Recent"
    case alphabetical = "A-Z"
    case nextDueDate = "Next Due Date"

    var id: String { rawValue }
  }

  /// The selected person is shared across the app through SelectionState, so that all views stay in sync without needing to pass the selection through the view hierarchy.
  @ObservationIgnored private let selectionState = SelectionState.shared

  // MARK: - Persistent Data Selection

  /// Selected person.
  var selectedPerson: Person? {
    get { selectionState.selectedPerson }
    set { selectionState.selectedPerson = newValue }
  }

  /// Selected mole.
  var selectedMole: Mole? {
    get { selectionState.selectedMole }
    set { selectionState.selectedMole = newValue }
  }

  /// Keeps list-driven navigation stable while detail view is open.
  var selectedMoleNavigationID: UUID?

  // MARK: - UI Flow State

  /// Showing add person.
  var showingAddPerson: Bool = false
  /// Showing edit person.
  var showingEditPerson: Bool = false
  /// Showing delete alert.
  var showingDeleteAlert: Bool = false
  /// Showing delete mole alert.
  var showingDeleteMoleAlert: Bool = false

  // MARK: - UI Animation State

  /// Slide edge.
  var slideEdge: Edge = .trailing

  // MARK: - Temporary Data State

  /// New person name.
  var newPersonName: String = ""
  /// Editing name.
  var editingName: String = ""
  /// Person to edit.
  var personToEdit: Person?
  /// Person to delete.
  var personToDelete: Person?
  /// Mole to delete.
  var moleToDelete: Mole?
  /// Captured image.
  var capturedImage: UIImage?
  /// Captured depth map.
  var capturedDepthMap: CVPixelBuffer?
  /// Captured confidence map.
  var capturedConfidenceMap: CVPixelBuffer?
  /// Captured camera intrinsics.
  var capturedIntrinsics: simd_float3x3?

  /// The data controller.
  private let dataController: DataController

  /// Creates overview state with the shared data controller dependency.
  /// - Parameter dataController: The controller used for person and mole persistence actions.
  init(dataController: DataController) {
    self.dataController = dataController
  }

  // MARK: - Person Initialization & Navigation

  /// Initializes the selected person if none is currently selected.
  /// Should be called when the list of people is loaded or changes.
  func initializeSelectionIfNeeded(with people: [Person]) {
    if selectedPerson == nil, let firstPerson: Person = people.first {
      selectedPerson = firstPerson
    }
  }

  /// Selects the previous person in the list, if possible, and sets the slide animation direction.
  /// - Parameter people: The current list of people to determine the index of the selected person.
  func selectPreviousPerson(from people: [Person]) {
    guard let current: Person = selectedPerson,
      let index: Array<Person>.Index = people.firstIndex(of: current),
      index > 0
    else { return }

    slideEdge = .leading
    withAnimation {
      selectedPerson = people[index - 1]
    }
  }

  /// Selects the next person in the list, if possible, and sets the slide animation direction.
  /// - Parameter people: The current list of people to determine the index of the selected person.
  func selectNextPerson(from people: [Person]) {
    guard let current: Person = selectedPerson,
      let index: Array<Person>.Index = people.firstIndex(of: current),
      index < people.count - 1
    else { return }

    slideEdge = .trailing
    withAnimation {
      selectedPerson = people[index + 1]
    }
  }

  // MARK: - Person CRUD Actions

  /// Validates and creates a new person, then selects them and resets the add person state.
  /// Should be called when confirming the addition of a new person.
  func confirmAddPerson() {
    let trimmedName = newPersonName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedName.isEmpty else {
      cancelAddPerson()
      return
    }

    let newPerson: Person = dataController.addPerson(name: trimmedName)
    selectedPerson = newPerson
    newPersonName = ""
    showingAddPerson = false
  }

  /// Resets the add person state without creating a new person.
  /// Should be called when cancelling the addition of a new person.
  func cancelAddPerson() {
    newPersonName = ""
    showingAddPerson = false
  }

  /// Starts the editing process for a person.
  /// - Parameter person: The person to edit.
  func startEditing(person: Person) {
    personToEdit = person
    editingName = person.name
    showingEditPerson = true
  }

  /// Validates and saves the edited person's name, then resets the edit state.
  /// Should be called when confirming the edit of a person.
  func confirmEdit() {
    let trimmedName = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
    if let person: Person = personToEdit, !trimmedName.isEmpty {
      dataController.rename(person, to: trimmedName)
    }
    cancelEdit()
  }

  /// Resets edit-related temporary state and dismisses the edit sheet.
  func cancelEdit() {
    personToEdit = nil
    editingName = ""
    showingEditPerson = false
  }

  /// Stores the person pending deletion and presents the delete confirmation alert.
  /// - Parameter person: The person targeted for deletion.
  func requestDelete(person: Person) {
    personToDelete = person
    showingDeleteAlert = true
  }

  /// Deletes the pending person and clears delete alert state.
  /// Also clears the current selection if the deleted person was selected.
  func confirmDeletePerson(from people: [Person]) {
    defer {
      personToDelete = nil
      showingDeleteAlert = false
    }

    guard let person: Person = personToDelete else { return }

    if selectedPerson == person, let index = people.firstIndex(of: person) {
      if people.count == 1 {
        selectedPerson = nil
      } else if index == 0 {
        selectedPerson = people[1]
      } else {
        selectedPerson = people.first
      }
      selectedMoleNavigationID = nil
    }

    if selectedMole?.person == person {
      selectedMole = nil
      selectedMoleNavigationID = nil
    }

    let personToRemove: Person = person
    Task { @MainActor in
      await Task.yield()
      dataController.delete(personToRemove)
    }
  }

  // MARK: - Mole Actions

  /// Stores the mole pending deletion and presents the delete confirmation alert.
  /// - Parameter mole: The mole targeted for deletion.
  func requestDelete(mole: Mole) {
    moleToDelete = mole
    showingDeleteMoleAlert = true
  }

  /// Updates the currently selected mole and keeps list-driven navigation in sync.
  /// - Parameter mole: The mole to select, or `nil` to clear the selection.
  func selectMole(_ mole: Mole?) {
    selectedMole = mole
    selectedMoleNavigationID = mole?.id
  }

  /// Deletes the pending mole and clears mole delete alert state.
  func confirmDeleteMole() {

    defer {
      moleToDelete = nil
      showingDeleteMoleAlert = false
    }

    guard let mole: Mole = moleToDelete else { return }

    dataController.delete(mole)

  }

  // MARK: - Overview Filtering & Sorting

  /// Returns unique body parts for a person's moles in alphabetical order.
  /// - Parameter person: The person whose mole body parts are listed.
  /// - Returns: Sorted, de-duplicated body part names.
  func availableBodyParts(for person: Person) -> [String] {
    Array(Set(person.moles.map(\.bodyPart)))
      .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
  }

  /// Returns moles filtered by selected body parts and sorted by the chosen strategy.
  /// - Parameters:
  ///   - person: The person whose moles are displayed.
  ///   - selectedBodyParts: Active body-part filters; empty means no filtering.
  ///   - sortOption: Sorting strategy applied after filtering.
  /// - Returns: Filtered and sorted moles.
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

  /// Returns the newest scan for the provided mole.
  /// - Parameter mole: The mole to inspect.
  /// - Returns: The most recently captured scan, or `nil` when none exist.
  func latestScan(for mole: Mole) -> MoleScan? {
    mole.scans
      .sorted { $0.captureDate > $1.captureDate }
      .first
  }

}
