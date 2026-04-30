import Testing
import UIKit
@testable import P8_Product

@MainActor
@Suite("Mole segmentation duplicate-name validation")
/// Tests for mole segmentation app state, covering duplicate-name validation logic.
struct MoleSegmentationAppStateTests {

    /// Creates a `Person` with a single mole using the given name.
    private func makePersonWithMole(named moleName: String) -> Person {
        let person = Person(name: "Alex")
        let mole = Mole(
            name: moleName,
            bodyPart: "Back",
            isReminderActive: true,
            reminderFrequency: nil,
            nextDueDate: nil,
            person: person
        )
        person.moles = [mole]
        return person
    }

    @Test("hasMole matches names case-insensitively and trims whitespace")
    func hasMoleUsesNormalizedNameMatching() {
        let dataController = DataController.shared
        let person = makePersonWithMole(named: "Back Mole")

        #expect(dataController.hasMole(named: " back mole ", for: person) == true)
        #expect(dataController.hasMole(named: "BACK MOLE", for: person) == true)
        #expect(dataController.hasMole(named: "Chest Mole", for: person) == false)
    }

    @Test("inline validation message is shown when a duplicate name is entered")
    func duplicateNameProducesInlineValidation() {
        let person = makePersonWithMole(named: "Back Mole")
        let state = MoleSegmentationAppState(dataController: .shared)
        state.selectedPersonForScan = person

        state.newMoleName = "back mole"

        #expect(state.newMoleNameValidationMessage != nil)
        #expect(state.canSaveNewMole == false)
    }

    @Test("save stays blocked for duplicate name without triggering alert")
    func duplicateNameBlocksSaveWithoutAlert() {
        let person = makePersonWithMole(named: "Back Mole")
        let state = MoleSegmentationAppState(dataController: .shared)
        state.selectedPersonForScan = person
        state.newMoleName = "Back Mole"
        state.testImage = UIImage()
        state.selectedBoxForMole = CGRect(x: 0, y: 0, width: 20, height: 20)

        state.handleNewMoleSelection()

        #expect(state.statusMessage == "Ready")
        switch state.activeAlert {
        case .none:
            #expect(Bool(true))
        case .some:
            Issue.record("Expected no alert for duplicate inline validation path")
        }
    }
}
