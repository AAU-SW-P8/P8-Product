import SwiftUI

@MainActor
@Observable
final class MoleDetailAppState {
	@ObservationIgnored private let selectionState = SelectionState.shared

	private let initialMole: Mole

	// MARK: - UI State
	var selectedIndex: Int = 0
	var showCompare: Bool = false
	var didOpenEvolution: Bool = false

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

	var shouldShowEvolutionButton: Bool {
		scans.count > 1
	}

	// MARK: - Actions

	func openEvolution() {
		didOpenEvolution = true
		selectionState.selectedPerson = activeMole.person
		selectionState.selectedMole = activeMole
		selectionState.pendingCompareMole = activeMole
		showCompare = true
	}

	func handleAppear() {
		if !didOpenEvolution {
			selectionState.selectedMole = initialMole
		}
	}

	func clampSelectedIndexIfNeeded() {
		if selectedIndex >= scans.count {
			selectedIndex = max(0, scans.count - 1)
		}
	}
}
