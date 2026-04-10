import SwiftUI
import SwiftData



/**
    The `CompareAppState` class manages the state for the Compare view, including the selected person, mole, metric, and carousel indices. It provides methods to update the selected person and mole while ensuring that dependent state is reset to prevent stale data from being displayed in the view.
 
    The class is marked as `@Observable` to allow SwiftUI views to react to changes in its properties, and it is annotated with `@MainActor` to ensure that all state updates occur on the main thread, which is necessary for UI updates.
    - Fields:
        - selectedPerson: The currently selected `Person` object, which determines the context for the displayed moles and scans.
        - selectedMole: The currently selected `Mole` object, which filters the displayed scans in the carousels.
        - selectedMetric: The currently selected `ChartMetric`, which determines the metric displayed in the charts.
        - selectedIndexTop: The index of the currently selected scan in the top carousel.
        - selectedIndexBottom: The index of the currently selected scan in the bottom carousel.
    - Methods:
        - selectPerson(_ person: Person?): Updates the selected person and resets the selected mole and carousel indices to ensure the view shows relevant data for the new selection.
        - selectMole(_ mole: Mole?): Updates the selected mole and resets the carousel indices to start from the first scan of the newly selected mole.
*/
@MainActor
@Observable
class CompareAppState {
    /// Shared selection state for the currently selected person, which is observed across multiple views to maintain a consistent selection.
    @ObservationIgnored private let selectionState = SelectionState.shared

    // MARK: - Persistent Data Selection
    var selectedMole: Mole?
    var selectedMetric: ChartMetric = .area
    var selectedIndexTop: Int = 0
    var selectedIndexBottom: Int = 0

    var selectedPerson: Person? {
        get { selectionState.selectedPerson }
        set { selectionState.selectedPerson = newValue }
    }

    init() {}

    // MARK: - Logic

    /**
     Selects a person and resets the dependent mole and carousel selections,
     so the view never shows stale state from a previously selected person.
     */
    func selectPerson(_ person: Person?) {
        selectedPerson = person
        selectedMole = nil
        selectedIndexTop = 0
        selectedIndexBottom = 0
    }

    /**
     Selects a mole and resets the carousel indices so both carousels start
     from the first scan of the newly selected mole.
     */
    func selectMole(_ mole: Mole?) {
        selectedMole = mole
        selectedIndexTop = 0
        selectedIndexBottom = 0
    }
}
