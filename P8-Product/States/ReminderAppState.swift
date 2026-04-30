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
    @ObservationIgnored private let dataController = DataController.shared

    // MARK: - Persistent Data Selection
    var reminderEnabled = true
    var defaultFrequency = "Weekly"
    var slideEdge: Edge = .trailing

    var selectedPerson: Person? {
        get { selectionState.selectedPerson }
        set { selectionState.selectedPerson = newValue }
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

    /**
     Creates a two-way binding for the reminder mode segmented options.

     - Parameter mole: The mole whose reminder mode should be read and updated.
     - Returns: A `Binding<String>` for `Default`, `Enabled`, or `Disabled`.
     */
    func reminderModeBinding(for mole: Mole) -> Binding<String> {
        Binding(
            get: { self.reminderMode(for: mole) },
            set: { newValue in
                switch newValue {
                case "Enabled":
                    mole.followDefaultReminderEnabled = false
                    mole.isReminderActive = true
                    self.updateDueDateForEnabledMoleOverride(mole)
                case "Disabled":
                    mole.followDefaultReminderEnabled = false
                    mole.isReminderActive = false
                    mole.nextDueDate = nil
                default:
                    mole.followDefaultReminderEnabled = true
                    mole.isReminderActive = self.reminderEnabled
                    if self.reminderEnabled {
                        self.updateDueDateForEnabledMoleOverride(mole)
                    } else {
                        mole.nextDueDate = nil
                    }
                }
                self.persistChanges()
            }
        )
    }

    private func updateDueDateForEnabledMoleOverride(_ mole: Mole) {
        dataController.recalculateNextDueDate(for: mole)
    }

    /**
    Updates a mole's reminder configuration and recalculates next due date.

    - Parameters:
        - mole: The mole being updated.
        - frequencyLabel: The selected frequency label (`Default`, `Weekly`, `Monthly`, or `Quarterly`).
    */
    func updateReminder(for mole: Mole, frequencyLabel: String) {
        if frequencyLabel == "Default" {
            mole.followDefault = true
            mole.reminderFrequency = nil
        } else {
            mole.followDefault = false
            mole.reminderFrequency = Frequency(rawValue: frequencyLabel.lowercased())
        }

        guard dataController.effectiveReminderEnabled(for: mole) else {
            mole.nextDueDate = nil
            persistChanges()
            return
        }

        dataController.recalculateNextDueDate(for: mole)
        persistChanges()
    }

    /**
     Resolves the current reminder mode label for a mole.

     - Parameter mole: The mole whose reminder mode should be evaluated.
     - Returns: `Default`, `Enabled`, or `Disabled`.
     */
    func reminderMode(for mole: Mole) -> String {
        if mole.followDefaultReminderEnabled ?? true {
            return "Default"
        }
        return mole.isReminderActive ? "Enabled" : "Disabled"
    }

    /**
     Sets the default reminder enabled state for the selected person.

     - Parameter newValue: The new value for the default reminder enabled state.
     */
    func setDefaultReminderEnabled(_ newValue: Bool) {
        selectedPerson?.defaultReminderEnabled = newValue
        updateDueDatesForDefaultReminderEnabledChange(newValue)
        persistChanges()
    }

    private func updateDueDatesForDefaultReminderEnabledChange(_ isEnabled: Bool) {
        guard let person = selectedPerson else { return }

        for mole in person.moles where mole.followDefaultReminderEnabled ?? true {
            if isEnabled {
                dataController.recalculateNextDueDate(for: mole)
            } else {
                mole.nextDueDate = nil
            }
        }
    }

    /**
     Sets the default reminder frequency for the selected person.

     - Parameter newValue: The new value for the default reminder frequency.
     */
    func setDefaultFrequency(_ newValue: String) {
        selectedPerson?.defaultReminderFrequency = newValue
        persistChanges()
    }

    /**
     Sets the selected person in the selection state.

     - Parameter newValue: The new `Person` to be selected, or `nil` to clear the selection.
     */
    func setSelectedPerson(_ newValue: Person?) {
        selectedPerson = newValue
    }

    /// Persists reminder-related mutations to the shared SwiftData context.
    private func persistChanges() {
        let context = dataController.container.mainContext
        do {
            try context.save()
        } catch {
            print("Failed to persist reminder changes: \(error)")
        }
    }
}
