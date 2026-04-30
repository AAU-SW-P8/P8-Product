import SwiftUI
import Foundation
import SwiftData

/// Observable state object that drives the mole detail and evolution screens.
@MainActor
@Observable
final class MoleDetailAppState {
	/// The pages available in the mole detail navigation.
	enum Page: String, CaseIterable, Identifiable {
		/// Shows detailed scan information for the selected mole.
		case detail = "Detail"
		/// Shows the evolution chart comparing two scans.
		case evolution = "Evolution"
		/// The stable identifier for the page.
		var id: Self { self }
	}

	/// Shared selection state used to synchronise the active mole across screens.
	@ObservationIgnored private let selectionState: SelectionState
	/// Data layer used for persistence and deletion operations.
	@ObservationIgnored private let dataController: DataController
	/// The mole used as the fallback when no global mole selection exists.
	private let initialMole: Mole

	// MARK: - UI State
	/// The currently visible page in the detail navigation.
	var selectedPage: Page = .detail
	/// Index of the currently displayed scan in the image carousel.
	var selectedIndex: Int = 0
	/// The metric (area or diameter) shown in the evolution chart.
	var selectedMetric: ChartMetric = .area
	/// Index of the older scan selected for evolution comparison.
	var selectedEvolutionTopIndex: Int = 0
	/// Index of the newer scan selected for evolution comparison.
	var selectedEvolutionBottomIndex: Int = 0
	/// When `true`, the detail view should be dismissed.
	var shouldDismissDetailView: Bool = false
	/// Whether the delete confirmation alert for a specific scan is visible.
	var showingDeleteDetailInstanceAlert: Bool = false
	/// The scan pending deletion confirmation.
	var detailScanToDelete: MoleScan?

	/// Creates state and dependencies for a mole detail flow.
	/// - Parameters:
	///   - mole: The mole shown when no global mole selection exists.
	///   - dataController: Data layer used for persistence and deletion.
	///   - selectionState: Shared selection state across app screens.
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
		activeMole.scans
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

	/// Initializes selection and chart indices when the view appears.
	/// If the selected person changed globally, this will request dismissal instead.
	func handleAppear() {
		dismissIfSelectedPersonChanged()
		guard !shouldDismissDetailView else {
			return
		}

		if selectionState.selectedMole == nil {
			selectionState.selectedMole = initialMole
		}
		setDefaultEvolutionIndices()
	}

	/// Selects a different mole within the active person context and resets carousel/evolution indices.
	/// - Parameter mole: The mole to make active.
	func selectMole(_ mole: Mole) {
		selectionState.selectedPerson = mole.person
		selectionState.selectedMole = mole
		selectedIndex = 0
		setDefaultEvolutionIndices()
	}

	/// Clamps all scan-related selected indices to valid bounds based on the current scan count.
	func clampSelectedIndicesIfNeeded() {
		let maxIndex: Int = max(0, scans.count - 1)
		selectedIndex = min(selectedIndex, maxIndex)
		selectedEvolutionTopIndex = min(selectedEvolutionTopIndex, maxIndex)
		selectedEvolutionBottomIndex = min(selectedEvolutionBottomIndex, maxIndex)
	}

	/// Marks the detail flow for dismissal if the globally selected person no longer matches this mole's person.
	func dismissIfSelectedPersonChanged() {
		let activeMolePersonID: UUID? = activeMole.person?.id
		let globallySelectedPersonID: UUID? = selectionState.selectedPerson?.id

		guard activeMolePersonID != globallySelectedPersonID else {
			return
		}

		selectionState.selectedMole = nil
		shouldDismissDetailView = true
	}

	/// Prepares deletion of the currently selected scan and triggers the delete confirmation alert.
	func requestDeleteSelectedDetailInstance() {
		guard let scan: MoleScan = ImageCarousel.selectedScan(in: scans, at: selectedIndex, for: activeMole) else {
			return
		}

		detailScanToDelete = scan
		showingDeleteDetailInstanceAlert = true
	}

	/// Confirms deletion of the pending scan, updates/removes related mole data, and adjusts UI selection state.
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
		let hasAnyScansLeft: Bool = selectedMole.scans.contains { $0 !== scan }
		if !hasAnyScansLeft {
			dataController.delete(selectedMole)
			selectionState.selectedMole = nil
			shouldDismissDetailView = true
			return
		}

		dataController.recalculateNextDueDate(for: selectedMole, excluding: scan)
		persistMoleChanges()

		clampSelectedIndicesIfNeeded()
	}

	/// Clears a pending dismiss request after the UI has consumed it.
	func consumeDismissRequest() {
		shouldDismissDetailView = false
	}

	/// Cancels scan deletion flow and hides the delete confirmation alert.
	func cancelDeleteSelectedDetailInstance() {
		detailScanToDelete = nil
		showingDeleteDetailInstanceAlert = false
	}



	/// Sets evolution comparison defaults to oldest (top) and newest (bottom) valid scan indices.
	private func setDefaultEvolutionIndices() {
		let maxIndex = max(0, scans.count - 1)
		selectedEvolutionTopIndex = maxIndex
		selectedEvolutionBottomIndex = 0
	}

	/// Persists any mole-related state changes to the main SwiftData context.
	private func persistMoleChanges() {
		do {
			try dataController.container.mainContext.save()
		} catch {
			print("Failed to update mole due date after deleting instance: \(error)")
		}
	}
}
