import Testing
import UIKit

@testable import P8_Product

/// Tests for mole segmentation app state, covering duplicate-name validation logic.
@Suite("Mole segmentation duplicate-name validation")
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

  /// Tests that hasMole uses normalized name matching.
  @Test("hasMole matches names case-insensitively and trims whitespace")
  @MainActor
  func hasMoleUsesNormalizedNameMatching() {
    let dataController = DataController.shared
    let person = makePersonWithMole(named: "Back Mole")

    #expect(dataController.hasMole(named: " back mole ", for: person) == true)
    #expect(dataController.hasMole(named: "BACK MOLE", for: person) == true)
    #expect(dataController.hasMole(named: "Chest Mole", for: person) == false)
  }

  /// Tests that an inline validation message is shown when a duplicate name is entered.
  @Test("inline validation message is shown when a duplicate name is entered")
  @MainActor
  func duplicateNameProducesInlineValidation() {
    let person = makePersonWithMole(named: "Back Mole")
    let state = MoleSegmentationAppState(dataController: .shared)
    state.selectedPersonForScan = person

    state.newMoleName = "back mole"

    #expect(state.newMoleNameValidationMessage != nil)
    #expect(state.canSaveNewMole == false)
  }

  /// Tests that save stays blocked for duplicate name without triggering alert.
  @Test("save stays blocked for duplicate name without triggering alert")
  @MainActor
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
