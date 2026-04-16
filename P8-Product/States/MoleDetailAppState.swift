import SwiftUI

@MainActor
@Observable
final class MoleDetailAppState {
	enum Page: String, CaseIterable, Identifiable {
		case detail = "Detail"
		case evolution = "Evolution"

		var id: Self { self }
	}

	@ObservationIgnored private let selectionState: SelectionState
	@ObservationIgnored private let dataController: DataController

	private let initialMole: Mole

	// MARK: - UI State
	var selectedPage: Page = .detail
	var selectedIndex: Int = 0
	var selectedMetric: ChartMetric = .area
	var selectedEvolutionTopIndex: Int = 0
	var selectedEvolutionBottomIndex: Int = 0
	var shouldDismissDetailView: Bool = false
	var showingDeleteDetailInstanceAlert: Bool = false
	var detailInstanceToDelete: MoleInstance?

	init(
		mole: Mole,
		dataController: DataController,
		selectionState: SelectionState
	) {
		self.initialMole = mole
		self.dataController = dataController
		self.selectionState = selectionState
	}

	// MARK: - Derived Data

	var activeMole: Mole {
		selectionState.selectedMole ?? initialMole
	}

	var scans: [MoleScan] {
		activeMole.instances
			.compactMap(\.moleScan)
			.sorted { $0.captureDate > $1.captureDate }
	}

	var molesForActivePerson: [Mole] {
		guard let person: Person = activeMole.person else {
			return [activeMole]
		}

		let sorted: [Mole] = person.moles.sorted {
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
		setDefaultEvolutionIndices()
	}

	func selectMole(_ mole: Mole) {
		selectionState.selectedPerson = mole.person
		selectionState.selectedMole = mole
		selectedIndex = 0
		setDefaultEvolutionIndices()
	}

	func clampSelectedIndicesIfNeeded() {
		let maxIndex: Int = max(0, scans.count - 1)
		selectedIndex = min(selectedIndex, maxIndex)
		selectedEvolutionTopIndex = min(selectedEvolutionTopIndex, maxIndex)
		selectedEvolutionBottomIndex = min(selectedEvolutionBottomIndex, maxIndex)
	}

	func requestDeleteSelectedDetailInstance() {
		guard let instance: MoleInstance = ImageCarousel.selectedInstance(in: scans, at: selectedIndex, for: activeMole) else {
			return
		}

		detailInstanceToDelete = instance
		showingDeleteDetailInstanceAlert = true
	}

	func confirmDeleteSelectedDetailInstance() {
		defer {
			detailInstanceToDelete = nil
			showingDeleteDetailInstanceAlert = false
		}

		guard let instance: MoleInstance = detailInstanceToDelete else {
			return
		}

		dataController.delete(instance)

		let selectedMole: Mole = activeMole
		let hasAnyScansLeft: Bool = selectedMole.instances.contains { $0.moleScan != nil }
		if !hasAnyScansLeft {
			dataController.delete(selectedMole)
			selectionState.selectedMole = nil
			shouldDismissDetailView = true
			return
		}

		clampSelectedIndicesIfNeeded()
	}

	func consumeDismissRequest() {
		shouldDismissDetailView = false
	}

	func cancelDeleteSelectedDetailInstance() {
		detailInstanceToDelete = nil
		showingDeleteDetailInstanceAlert = false
	}



	private func setDefaultEvolutionIndices() {
		let maxIndex = max(0, scans.count - 1)
		selectedEvolutionTopIndex = maxIndex
		selectedEvolutionBottomIndex = 0
	}
}
