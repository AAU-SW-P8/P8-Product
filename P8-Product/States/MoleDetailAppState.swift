import SwiftUI

@MainActor
@Observable
final class MoleDetailAppState {
	enum Page: String, CaseIterable, Identifiable {
		case detail = "Detail"
		case evolution = "Evolution"

		var id: Self { self }
	}

	@ObservationIgnored private let selectionState = SelectionState.shared

	private let initialMole: Mole

	// MARK: - UI State
	var selectedPage: Page = .detail
	var selectedIndex: Int = 0
	var selectedMetric: ChartMetric = .area
	var selectedEvolutionTopIndex: Int = 0
	var selectedEvolutionBottomIndex: Int = 0

	init(mole: Mole) {
		self.initialMole = mole
	}

	// MARK: - Derived Data

	var activeMole: Mole {
		selectionState.selectedMole ?? initialMole
	}

	var scans: [MoleScan] {
		activeMole.instances
			.compactMap(\.moleScan)
			.sorted { $0.captureDate < $1.captureDate }
	}

	var molesForActivePerson: [Mole] {
		guard let person = activeMole.person else {
			return [activeMole]
		}

		let sorted = person.moles.sorted {
			if $0.bodyPart.localizedCaseInsensitiveCompare($1.bodyPart) == .orderedSame {
				return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
			}
			return $0.bodyPart.localizedCaseInsensitiveCompare($1.bodyPart) == .orderedAscending
		}

		return sorted.isEmpty ? [activeMole] : sorted
	}

	// MARK: - Actions

	func handleAppear() {
		selectionState.selectedPerson = initialMole.person
		selectionState.selectedMole = initialMole
	}

	func selectMole(_ mole: Mole) {
		selectionState.selectedPerson = mole.person
		selectionState.selectedMole = mole
		selectedIndex = 0
		selectedEvolutionTopIndex = 0
		selectedEvolutionBottomIndex = 0
	}

	func clampSelectedIndicesIfNeeded() {
		let maxIndex = max(0, scans.count - 1)
		selectedIndex = min(selectedIndex, maxIndex)
		selectedEvolutionTopIndex = min(selectedEvolutionTopIndex, maxIndex)
		selectedEvolutionBottomIndex = min(selectedEvolutionBottomIndex, maxIndex)
	}
}
