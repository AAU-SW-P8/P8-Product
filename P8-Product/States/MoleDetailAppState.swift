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

	// MARK: - Actions

	func handleAppear() {
		selectionState.selectedPerson = initialMole.person
		selectionState.selectedMole = initialMole
	}

	func clampSelectedIndicesIfNeeded() {
		let maxIndex = max(0, scans.count - 1)
		selectedIndex = min(selectedIndex, maxIndex)
		selectedEvolutionTopIndex = min(selectedEvolutionTopIndex, maxIndex)
		selectedEvolutionBottomIndex = min(selectedEvolutionBottomIndex, maxIndex)
	}
}
