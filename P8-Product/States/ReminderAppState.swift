import SwiftUI
import SwiftData


/**
    The `ReminderAppState` class manages the state for the Reminder view, including the selected person and their associated reminder settings. It provides methods to update the selected person while ensuring that dependent state is reset to prevent stale data from being displayed in the view.
 
    The class is marked as `@Observable` to allow SwiftUI views to react to changes in its properties, and it is annotated with `@MainActor` to ensure that all state updates occur on the main thread, which is necessary for UI updates.
    - Fields:
        - selectedPerson: The currently selected `Person` object, which determines the context for the displayed reminder settings.
    - Methods:
        - selectPerson(_ person: Person?): Updates the selected person and resets any dependent state to ensure the view shows relevant data for the new selection.
*/
@MainActor
@Observable
class ReminderAppState {
    // The selected person is shared across the app through SelectionState, so that all views stay in sync without needing to pass the selection through the view hierarchy.
    @ObservationIgnored private let selectionState = SelectionState.shared

    // MARK: - Persistent Data Selection
    var reminderEnabled = true
    var defaultFrequency = "Weekly"
    var slideEdge: Edge = .trailing

    var selectedPerson: Person? {
        get { selectionState.selectedPerson }
        set { selectionState.selectedPerson = newValue }
    }

    private let dataController: DataController
    
    init(dataController: DataController) {
        self.dataController = dataController
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
     Syncs local UI state from the currently selected person.
     */
    func syncSelectionState() {
        guard let person = selectedPerson else { return }
        reminderEnabled = person.defaultReminderEnabled
        defaultFrequency = displayFrequency(for: person)
    }


    /**
     Converts a person's stored default frequency to a display label.

     - Parameter person: The person whose default frequency is displayed.
     - Returns: `Weekly`, `Monthly`, or `Quarterly`.
     */
    func displayFrequency(for person: Person) -> String {
        switch person.defaultReminderFrequency.lowercased() {
        case "weekly":
            return "Weekly"
        case "monthly":
            return "Monthly"
        case "quarterly":
            return "Quarterly"
        default:
            return "Weekly"
        }
    }

}