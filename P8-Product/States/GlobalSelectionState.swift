import SwiftUI

/**
    SelectionState is a shared, observable class that holds the currently selected person across the app.
    It is designed to be accessed and modified by multiple view models and views without needing to pass it through the view hierarchy.
    - Properties
        - selectedPerson: The currently selected Person object, which can be nil if no selection has been made.
    - Usage
        - Views and view models can read from and write to `SelectionState.shared.selectedPerson` to get or set the current selection. 
          This allows for a centralized state management approach for the selected person across different parts of the app.
*/
@MainActor
@Observable
final class SelectionState {
    static let shared = SelectionState()

    var selectedPerson: Person?
    var selectedMole: Mole?

    private init() {}
}
