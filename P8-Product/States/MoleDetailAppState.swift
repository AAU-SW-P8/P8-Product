import SwiftUI
import Foundation
import SwiftData

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
	var detailScanToDelete: MoleScan?

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
		dismissIfSelectedPersonChanged()
		guard !shouldDismissDetailView else {
			return
		}

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

	func dismissIfSelectedPersonChanged() {
		let activeMolePersonID: UUID? = activeMole.person?.id
		let globallySelectedPersonID: UUID? = selectionState.selectedPerson?.id

		guard activeMolePersonID != globallySelectedPersonID else {
			return
		}

		selectionState.selectedMole = nil
		shouldDismissDetailView = true
	}

	func requestDeleteSelectedDetailInstance() {
		guard let scan: MoleScan = ImageCarousel.selectedScan(in: scans, at: selectedIndex, for: activeMole) else {
			return
		}

		detailScanToDelete = scan
		showingDeleteDetailInstanceAlert = true
	}

	func confirmDeleteSelectedDetailInstance() {
		defer {
			detailScanToDelete = nil
			showingDeleteDetailInstanceAlert = false
		}

		guard let scan: MoleScan = detailScanToDelete else {
			return
		}

		dataController.delete(scan)

		let selectedMole: Mole = activeMole
		let hasAnyScansLeft: Bool = selectedMole.instances.contains { $0 !== instance && $0.moleScan != nil }
		if !hasAnyScansLeft {
			dataController.delete(selectedMole)
			selectionState.selectedMole = nil
			shouldDismissDetailView = true
			return
		}

		dataController.recalculateNextDueDate(for: selectedMole, excluding: instance)
		persistMoleChanges()

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

	private func persistMoleChanges() {
		do {
			try dataController.container.mainContext.save()
		} catch {
			print("Failed to update mole due date after deleting instance: \(error)")
		}
	}
}
