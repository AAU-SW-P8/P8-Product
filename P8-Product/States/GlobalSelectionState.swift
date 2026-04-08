import SwiftUI

@MainActor
@Observable
final class SelectionState {
    static let shared = SelectionState()

    var selectedPerson: Person?

    private init() {}
}