import SwiftUI
import SwiftData

@MainActor
@Observable
class CompareAppState {
    // MARK: - Persistent Data Selection
    var selectedPerson: Person?
    var selectedMole: Mole?
    var selectedMetric: ChartMetric = .area
    var selectedIndexTop: Int = 0
    var selectedIndexBottom: Int = 0

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
