//
// MoleDetailView.swift
// P8-Product
//

import SwiftUI

/// A view that displays detailed information about a specific mole, including its scans and evolution over time. The view allows users to switch between a detail view showing individual scans and an evolution view comparing multiple scans. It also provides functionality for deleting scans and selecting different moles for the same person. The view is designed to handle various states, such as when there are no scans available, and includes accessibility features for better user experience.
/// - Parameters:
///     - appState: The state object that manages the data and logic for the mole detail view, including the selected mole, its scans, and user interactions such as deleting scans or switching between different moles. The app state is initialized with the specific mole to be displayed and is responsible for handling all related actions and data updates within the view.
///     - dismiss: An environment variable that allows the view to dismiss itself when certain conditions are met, such as when the selected person changes or when the user confirms the deletion of a scan. This provides a way for the view to navigate back to the previous screen in response to user actions or state changes.
struct MoleDetailView: View {
    @State private var appState: MoleDetailAppState
    @Environment(\.dismiss) private var dismiss

    @MainActor
    init(mole: Mole) {
        _appState = State(
            initialValue: MoleDetailAppState(
                mole: mole,
                dataController: DataController.shared,
                selectionState: SelectionState.shared
            )
        )
    }

    // MARK: - View Body
    var body: some View {
        @Bindable var appState = appState

        VStack(spacing: 0) {
            Picker("View", selection: $appState.selectedPage) {
                ForEach(MoleDetailAppState.Page.allCases) { page in
                    Text(page.rawValue).tag(page)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)
            .accessibilityIdentifier("moleDetailPagePicker")

            if appState.selectedPage == .detail {
                // If there are no scans, show a placeholder message. Otherwise, show the image carousel with the mole's scans.
                // Should not happen that there are no scans in the detail view, since we require at least one scan to create a mole, but we handle it just in case.
                if appState.scans.isEmpty {
                    Spacer()
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No scans yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                    Spacer()
                } else {
                    // MARK: - Details View with single carousel
                    // Show a single image carousel with all scans for the selected mole, allowing users to swipe through their scans and view details for each one. 
                    // The carousel includes functionality for deleting the currently selected scan, with confirmation handled by the app state.
                    HStack(spacing: 0) {
                        ImageCarousel(
                            scans: appState.scans,
                            mole: appState.activeMole,
                            selectedIndex: $appState.selectedIndex,
                            onDeleteSelectedScan: {
                                appState.requestDeleteSelectedDetailInstance()
                            },
                            side: .both // Full circle for detail view
                        )
                            .frame(maxWidth: 420)
                            .accessibilityIdentifier("detailCarousel")

                    }
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                    .padding(.horizontal)
                    .padding(.top, 8)

                    if let nextDueDateSummary = nextDueDateSummary(for: appState.activeMole) {
                        nextDueDateSummary
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.top, 10)
                            .accessibilityIdentifier("moleDetailNextDueDateSummary")
                    }
                    Spacer()
                }
            } else {
                // MARK: - Evolution View start
                // If there are no scans, show a placeholder message. Otherwise, show the dual image carousel for comparing scans and the chart view for metric evolution.
                // Should not happen that there are no scans in the detail view, since we require at least one scan to create a mole, but we handle it just in case.
                if appState.scans.isEmpty {
                    Spacer()
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No scans yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                    Spacer()
                } else {
                    ScrollView {
                        // MARK: - Evolution View with dual carousel and chart
                        // If there are multiple scans:
                        // show the dual carousel for comparing two scans side by side. 
                        // show the metric evolution chart for the selected metric, allowing users to track changes in their mole's characteristics over time.
                        if appState.scans.count > 1 {
                            HStack(spacing: 0) {
                                ImageCarousel(
                                    scans: appState.scans,
                                    mole: appState.activeMole,
                                    selectedIndex: $appState.selectedEvolutionTopIndex,
                                    side: .left,
                                    otherSelectedIndex: appState.selectedEvolutionBottomIndex
                                )
                                .accessibilityIdentifier("leftCarousel")

                                Divider()

                                ImageCarousel(
                                    scans: appState.scans,
                                    mole: appState.activeMole,
                                    selectedIndex: $appState.selectedEvolutionBottomIndex,
                                    side: .right,
                                    otherSelectedIndex: appState.selectedEvolutionTopIndex
                                )
                                .accessibilityIdentifier("rightCarousel")
                            }
                            .accessibilityElement(children: .contain)
                            .accessibilityIdentifier("dualCarouselContainer")
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color(.secondarySystemBackground))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                            )
                            .padding(.horizontal)
                            .padding(.top, 8)

                            VStack(spacing: 2) {
                                Text("Choose a metric evolution:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                Picker("Metric", selection: $appState.selectedMetric) {
                                    ForEach(ChartMetric.allCases) { metric in
                                        Text(metric.title).tag(metric)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .padding(.horizontal)
                                .padding(.top, 8)
                                .accessibilityIdentifier("metricPicker")

                                ChartView(
                                    mole: appState.activeMole,
                                    metric: appState.selectedMetric,
                                    scans: appState.scans,
                                    topSelectedIndex: appState.selectedEvolutionTopIndex,
                                    bottomSelectedIndex: appState.selectedEvolutionBottomIndex
                                )
                            }
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color(.secondarySystemBackground))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                            )
                            .padding(.horizontal)
                            .padding(.top, 8)
                        } else {
                            // MARK: - Evolution View with single carousel and no chart
                            // If there is only one scan, show the image carousel without the option to compare or track metric evolution, 
                            // and display a message prompting the user to add more scans to unlock these features.
                            HStack(spacing: 0) {
                                ImageCarousel(
                                    scans: appState.scans,
                                    mole: appState.activeMole,
                                    selectedIndex: $appState.selectedEvolutionBottomIndex,
                                    side: .right,
                                    otherSelectedIndex: appState.selectedEvolutionTopIndex // <-- Added
                                )
                                .accessibilityIdentifier("singleCarousel")
                            }
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color(.secondarySystemBackground))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                            )
                            .padding(.horizontal)
                            .padding(.top, 8)

                            Text("Add one more scan to unlock trend comparison.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.top, 12)
                        }
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        // Handle the delete scan confirmation alert, showing a destructive option to confirm deletion and a cancel option to abort. The alert is triggered by the app state when the user requests to delete a scan, and the actions are handled by the app state to perform the actual deletion or cancel it.
        .alert("Delete Scan", isPresented: $appState.showingDeleteDetailInstanceAlert) {
            Button("Delete", role: .destructive) {
                appState.confirmDeleteSelectedDetailInstance()
            }
            Button("Cancel", role: .cancel) {
                appState.cancelDeleteSelectedDetailInstance()
            }
        } message: {
            Text("Are you sure you want to delete this scan?")
        }
        // The toolbar contains a menu for selecting different moles associated with the same person, allowing users to quickly switch between moles without going back to the overview screen. 
        // The menu displays the names of the moles and indicates the currently selected mole with a checkmark. 
        // Selecting a mole from the menu updates the active mole in the app state, which in turn updates the displayed scans and details in the view.
        .toolbar {
            ToolbarItem(placement: .principal) {
                Menu {
                    ForEach(appState.molesForActivePerson) { mole in
                        Button {
                            appState.selectMole(mole)
                        } label: {
                            if mole.id == appState.activeMole.id {
                                Label(mole.name, systemImage: "checkmark")
                            } else {
                                Text(mole.name)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(appState.activeMole.name)
                            .font(.headline)
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                            .fontWeight(.semibold)
                    }
                }
                .accessibilityIdentifier("moleDetailMolePicker")
            }
        }
        .onAppear {
            appState.handleAppear()
        }
        .onChange(of: appState.scans.count) {
            appState.clampSelectedIndicesIfNeeded()
        }
        .onChange(of: SelectionState.shared.selectedPerson?.id) {
            appState.dismissIfSelectedPersonChanged()
        }
        .onChange(of: appState.shouldDismissDetailView) { _, shouldDismiss in
            guard shouldDismiss else { return }
            dismiss()
            appState.consumeDismissRequest()
        }
    }

    // MARK: - Helpers

    private func nextDueDateSummary(for mole: Mole) -> Text? {
        guard let nextDueDate = mole.nextDueDate else { return nil }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dueDay = calendar.startOfDay(for: nextDueDate)
        let daysUntilDue = calendar.dateComponents([.day], from: today, to: dueDay).day ?? 0
        let dayLabel = daysUntilDue == 1 ? "day" : "days"

        let bellImage: Text = Text(Image(systemName: "bell.fill"))
            .foregroundStyle(.orange)

        return bellImage + Text(" Next due date: \(nextDueDate.formatted(.dateTime.year().month().day())) (in \(daysUntilDue) \(dayLabel))")
    }

}
