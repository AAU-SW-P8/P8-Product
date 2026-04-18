// 
// OverviewView.swift
// P8-Product
//

import SwiftUI
import SwiftData
import UIKit

/**
 The `OverviewView` is the main interface for displaying and managing people, their moles, and associated scans. It provides navigation between people, a list of their moles, and actions to add/edit/delete people and moles. The view relies on `OverviewAppState` for managing its state and interactions with the data layer.
 */
public struct OverviewView: View {
    @Query(sort: \Person.createdAt) private var people: [Person]
    
    @State private var appState = OverviewAppState(dataController: .shared)
    
    public init() {}
    
    public var body: some View {
        OverviewContentView(appState: appState, people: people)
    }
}

private struct OverviewContentView: View {
    private enum MoleSortOption: String, CaseIterable, Identifiable {
        case recent = "Recent"
        case alphabetical = "A-Z"

        var id: String { rawValue }
    }

    private let bodyPartRowHeight: CGFloat = 34
    private let bodyPartMaxVisibleRows: CGFloat = 5

    // Declared at the top of the struct, so ALL subviews below can see it!
    @Bindable var appState: OverviewAppState
    var people: [Person]

    @State private var selectedBodyParts: Set<String> = []
    @State private var sortOption: MoleSortOption = .recent
    @State private var showingFilters: Bool = false
    @State private var showingBodyPartDropdown: Bool = false
    
    var body: some View {
        navigationContent
            .modifier(OverviewAlertsModifier(appState: appState))
    }

    private var navigationContent: some View {
        NavigationStack {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 0) {
                    headerView
                    personSelectorView
                    Divider()
                    moleListView
                    Spacer()
                }

                if showingFilters {
                    Color.black.opacity(0.001)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture {
                            closeFilterPopup()
                        }
                        .zIndex(1)
                }

                if showingFilters {
                    filterPopupView
                        .padding(.top, 64)
                        .padding(.trailing, 12)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(2)
                }
            }
            .onAppear {
                appState.initializeSelectionIfNeeded(with: people)
            }
            .onChange(of: people) { _, newValue in
                appState.initializeSelectionIfNeeded(with: newValue)
            }
            .onChange(of: appState.selectedPerson?.id) { _, _ in
                // Keep live filter choices when switching pages/person, but drop options that are no longer valid.
                selectedBodyParts = selectedBodyParts.intersection(Set(availableBodyParts))
                closeFilterPopup()
            }
            .onChange(of: showingFilters) { _, isVisible in
                if !isVisible {
                    showingBodyPartDropdown = false
                }
            }
            .onDisappear {
                closeFilterPopup()
            }
        }
    }

    
    
    // MARK: - Subviews
    
    private var headerView: some View {
        HStack {
            Text("Mole Overview")
                .font(.largeTitle)
                .fontWeight(.bold)
            Spacer()
            Button(action: {
                showingFilters ? closeFilterPopup() : openFilterPopup()
            }) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44)
            }
            .accessibilityIdentifier("overviewFilterButton")
            .accessibilityLabel("Open Filters")
            Button(action: {
                appState.showingAddPerson = true
            }) {
                Image(systemName: "person.fill.badge.plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal)
        .padding(.top)
        .background(Color(.systemGray6))
    }
    
    private var personSelectorView: some View {
        HStack {
            Button(action: { appState.selectPreviousPerson(from: people) }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44)
            }
            .disabled(appState.selectedPerson == people.first || people.isEmpty)
            .opacity((appState.selectedPerson == people.first || people.isEmpty) ? 0.3 : 1.0)
            
            ZStack {
                if let person = appState.selectedPerson {
                    Text(person.name)
                        .font(.system(size: 18, weight: .semibold))
                        .lineLimit(1)
                        .foregroundColor(.primary)
                        .contextMenu {
                            Button {
                                appState.startEditing(person: person)
                            } label: {
                                Label("Edit Name", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                appState.requestDelete(person: person)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .background(Color(.systemGray6))
                        .id(person)
                        .transition(.asymmetric(
                            insertion: .move(edge: appState.slideEdge).combined(with: .opacity),
                            removal: .move(edge: appState.slideEdge == .leading ? .trailing : .leading).combined(with: .opacity)
                        ))
                } else {
                    Text("No Person Selected")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .clipped()
            
            Button(action: { appState.selectNextPerson(from: people) }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44)
            }
            .disabled(appState.selectedPerson == people.last || people.isEmpty)
            .opacity((appState.selectedPerson == people.last || people.isEmpty) ? 0.3 : 1.0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
    
    private var moleListView: some View {
        ZStack {
            if let person: Person = appState.selectedPerson {
                let moles = displayedMoles(for: person)

                List {
                    ForEach(moles) { mole in
                        NavigationLink(
                            destination: MoleDetailView(mole: mole),
                            tag: mole.id,
                            selection: selectedMoleIDBinding(for: person)
                        ) {
                            moleRow(for: mole, person: person)
                        }
                        .accessibilityIdentifier("overviewMoleRow_\(mole.name)")
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                appState.requestDelete(mole: mole) // Perfectly in scope here!
                            } label: {
                                Label("Delete", systemImage: "trash.fill")
                            }
                            .accessibilityIdentifier("overviewDeleteMoleButton_\(mole.name)")
                            .tint(.red)
                        }
                    }
                }
                .listStyle(.plain)
                .id(person)
                .transition(.asymmetric(
                    insertion: .move(edge: appState.slideEdge),
                    removal: .move(edge: appState.slideEdge == .leading ? .trailing : .leading)
                ))
            }
        }
    }

    private func selectedMoleIDBinding(for person: Person) -> Binding<UUID?> {
        Binding(
            get: { appState.selectedMoleNavigationID },
            set: { newID in
                let selected = person.moles.first { $0.id == newID }
                appState.selectMole(selected)
            }
        )
    }

    private var filterPopupView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Filter & Sort")
                    .font(.headline)
                    .accessibilityIdentifier("overviewFilterPopupTitle")
                Spacer()
                Picker("Sort", selection: $sortOption) {
                    ForEach(MoleSortOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 110)
                .accessibilityIdentifier("overviewSortPicker")
                .accessibilityLabel("Sort Picker")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Body Parts")
                    .font(.subheadline.weight(.semibold))

                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        showingBodyPartDropdown.toggle()
                    }
                } label: {
                    HStack {
                        Text(selectedBodyPartsSummary)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: showingBodyPartDropdown ? "chevron.up" : "chevron.down")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("overviewBodyPartDropdownButton")
                .accessibilityLabel("Body Part Filter")

                if showingBodyPartDropdown {
                    VStack(alignment: .leading, spacing: 6) {
                        if availableBodyParts.isEmpty {
                            Text("No body parts available")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            HStack {
                                Button("Select All") {
                                    selectedBodyParts = Set(availableBodyParts)
                                }
                                .buttonStyle(.plain)
                                .font(.subheadline)
                                .accessibilityIdentifier("overviewBodyPartSelectAllButton")

                                Spacer()

                                Button("Clear") {
                                    selectedBodyParts = []
                                }
                                .buttonStyle(.plain)
                                .font(.subheadline)
                                .accessibilityIdentifier("overviewBodyPartClearButton")
                            }
                            .foregroundColor(.secondary)

                            ScrollView {
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(availableBodyParts, id: \.self) { bodyPart in
                                        Button {
                                            toggleBodyPart(bodyPart)
                                        } label: {
                                            HStack(spacing: 8) {
                                                Image(systemName: selectedBodyParts.contains(bodyPart) ? "checkmark.circle.fill" : "circle")
                                                    .foregroundColor(selectedBodyParts.contains(bodyPart) ? .accentColor : .secondary)
                                                Text(bodyPart)
                                                    .foregroundColor(.primary)
                                                Spacer()
                                            }
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 6)
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityIdentifier("overviewBodyPartOption_\(bodyPart.replacingOccurrences(of: " ", with: "_"))")
                                    }
                                }
                            }
                            .frame(height: bodyPartDropdownHeight)
                        }
                    }
                    .padding(10)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .accessibilityIdentifier("overviewBodyPartDropdownList")
                }
            }

            HStack {
                Button("Reset") {
                    selectedBodyParts = []
                    sortOption = .recent
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .accessibilityIdentifier("overviewFilterResetButton")

                Spacer()
                Button("Done") {
                    closeFilterPopup()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("overviewFilterDoneButton")
            }

            Text("Filter Popup Visible")
                .font(.caption2)
                .foregroundColor(.clear)
                .accessibilityIdentifier("overviewFilterPopupVisibleMarker")
        }
        .padding()
        .frame(width: 320)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
        .accessibilityIdentifier("overviewFilterPopup")
    }

    private func openFilterPopup() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
            showingFilters = true
        }
    }

    private func closeFilterPopup() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
            showingBodyPartDropdown = false
            showingFilters = false
        }
    }

    private var selectedBodyPartsSummary: String {
        if selectedBodyParts.isEmpty {
            return "All body parts"
        }

        return selectedBodyParts
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            .joined(separator: ", ")
    }

    private var bodyPartDropdownHeight: CGFloat {
        let rowCount = min(CGFloat(availableBodyParts.count), bodyPartMaxVisibleRows)
        let minRows: CGFloat = availableBodyParts.isEmpty ? 1 : rowCount
        return max(bodyPartRowHeight, minRows * bodyPartRowHeight)
    }

    private var availableBodyParts: [String] {
        guard let person = appState.selectedPerson else { return [] }

        return Array(Set(person.moles.map(\.bodyPart)))
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private func displayedMoles(for person: Person) -> [Mole] {
        let filtered = person.moles.filter { mole in
            let matchesBodyPart = selectedBodyParts.isEmpty || selectedBodyParts.contains(mole.bodyPart)
            return matchesBodyPart
        }

        switch sortOption {
        case .alphabetical:
            return filtered.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        case .recent:
            return filtered.sorted {
                let lhsDate = latestScan(for: $0)?.captureDate ?? .distantPast
                let rhsDate = latestScan(for: $1)?.captureDate ?? .distantPast
                return lhsDate > rhsDate
            }
        }
    }

    private func toggleBodyPart(_ bodyPart: String) {
        if selectedBodyParts.contains(bodyPart) {
            selectedBodyParts.remove(bodyPart)
        } else {
            selectedBodyParts.insert(bodyPart)
        }
    }

    private func moleRow(for mole: Mole, person: Person) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 80, height: 80)
                    .cornerRadius(8)

                if let data = latestScan(for: mole)?.imageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .cornerRadius(8)
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.5))
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(mole.name)
                        .font(.system(size: 20, weight: .semibold))
                    if effectiveReminderEnabled(for: mole, person: person) {
                        Image(systemName: "bell.fill")
                            .foregroundColor(.orange)
                            .accessibilityIdentifier("overviewReminderIcon_\(mole.name)")
                    }
                }
                Text(mole.bodyPart)
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .contentShape(Rectangle())
        .padding(.vertical, 8)
    }

    private func effectiveReminderEnabled(for mole: Mole, person: Person) -> Bool {
        if mole.followDefaultReminderEnabled ?? true {
            return person.defaultReminderEnabled
        }
        return mole.isReminderActive
    }

    private func latestScan(for mole: Mole) -> MoleScan? {
        mole.instances
            .compactMap(\.moleScan)
            .sorted { $0.captureDate > $1.captureDate }
            .first
    }
}

private struct OverviewAlertsModifier: ViewModifier {
    @Bindable var appState: OverviewAppState

    func body(content: Content) -> some View {
        content
            .alert("Add Person", isPresented: $appState.showingAddPerson) {
                TextField("Name", text: $appState.newPersonName)
                Button("Add") { appState.confirmAddPerson() }
                Button("Cancel", role: .cancel) { appState.cancelAddPerson() }
            }
            .alert("Edit Person", isPresented: $appState.showingEditPerson) {
                TextField("Name", text: $appState.editingName)
                Button("Save") { appState.confirmEdit() }
                Button("Cancel", role: .cancel) { appState.cancelEdit() }
            }
            .alert("Delete Person", isPresented: $appState.showingDeleteAlert) {
                Button("Delete", role: .destructive) { appState.confirmDeletePerson() }
                Button("Cancel", role: .cancel) {
                    appState.personToDelete = nil
                }
            } message: {
                Text(deletePersonMessage)
            }
            .alert("Delete Mole", isPresented: $appState.showingDeleteMoleAlert) {
                Button("Delete", role: .destructive) { appState.confirmDeleteMole() }
                Button("Cancel", role: .cancel) {
                    appState.moleToDelete = nil
                }
            } message: {
                Text(deleteMoleMessage)
            }
    }

    private var deletePersonMessage: String {
        "Are you sure you want to delete \(appState.personToDelete?.name ?? "this person")?"
    }

    private var deleteMoleMessage: String {
        "Are you sure you want to delete \(appState.moleToDelete?.name ?? "this mole")?"
    }
}
