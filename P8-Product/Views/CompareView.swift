//
// CompareView.swift
// P8-Product
//

import SwiftUI
import SwiftData

/**
    CompareView is the main entry point for the comparison feature of the app. 
    It fetches all people from the database and manages the state for selecting a person, mole, and metric to compare. 
    It delegates the actual UI rendering to CompareContentView, which handles the different states of data availability and user interaction.
*/
public struct CompareView: View {
    /// Fetches all people from the database, sorted by their creation date, to populate the selection options in the UI.
    @Query(sort: \Person.createdAt) private var people: [Person]

    /// The state object that manages the selected person, mole, metric, and scan indices for the carousels
    @State private var appState = CompareAppState()

    public init() {}

    /// The body of the CompareView, which passes the fetched people and the state object to the CompareContentView for rendering. 
    public var body: some View {
        CompareContentView (appState: appState, people: people)
    }
}

/**
    CompareContentView is the main view for comparing mole scans across different people and moles. 
    It allows users to select a person and a mole, and then view the scans associated with that mole. 
    If multiple scans are available, it also provides a chart to visualize the evolution of selected metrics over time.
    - Fields
        - people: A list of all people in the database, sorted by creation date.
        - appState: The state object that manages the selected person, mole, metric, and scan indices for the carousels.
    - Body
        - Displays a title and handles three main states:
            1. No people in the database: Shows an empty state with instructions.
            2. People exist but no scans for the selected person/mole: Shows prompts to select a person/mole or capture scans.
            3. Scans exist: Displays carousels of images and a chart for metric evolution if multiple scans are available.
*/
private struct CompareContentView: View {
    @Bindable var appState: CompareAppState
    var people: [Person]

    /// Extracts and sorts the mole scans for the currently selected mole, if any. Returns an empty array if no mole is selected or if there are no scans.
    private var scans: [MoleScan] {
        guard let mole = appState.selectedMole else { return [] }
        return mole.instances
            .compactMap(\.moleScan)
            .sorted { $0.captureDate < $1.captureDate }
    }

    /// Checks if the currently selected person has any scans across all their moles. This is used to determine which prompts to show in the UI when no scans are available.
    private var selectedPersonHasAnyScans: Bool {
        guard let selectedPerson = appState.selectedPerson else { return false }
        return selectedPerson.moles.contains { mole in
            mole.instances.contains { $0.moleScan != nil }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Compare")
                .font(.largeTitle)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top)
                .accessibilityIdentifier("compareTitle")

            /// Handles the different states of the UI based on the availability of people and scans in the database.
            if people.isEmpty {
                Spacer()
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("No data yet")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
                    .accessibilityIdentifier("emptyStateTitle")
                Text("Add a person and capture some moles to compare them here.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .accessibilityIdentifier("emptyStateMessage")
                Spacer()
            } else {
                selectorBar
                    .padding(.top, 8)

                /// Shows different prompts based on the state of the selected person and mole, guiding the user to select a person, select a mole, or capture scans if none exist. If scans are available, it shows the carousels and chart for comparison.
                if scans.isEmpty {
                    Spacer()
                    Image(systemName: "photo")
                        .font(.system(size: 36))
                        .foregroundColor(.gray.opacity(0.4))
                    if appState.selectedPerson == nil {
                        Text("Select a person")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .accessibilityIdentifier("selectPersonPrompt")
                    } 
                    else if !selectedPersonHasAnyScans {
                        Text("You haven't captured any moles for \(appState.selectedPerson!.name) yet")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .accessibilityIdentifier("makeScanBeforeCompareMessage")
                    } else if appState.selectedMole == nil {
                        Text("Select a mole")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .accessibilityIdentifier("selectMolePrompt")
                    } else {
                        Text("No scans for \(appState.selectedMole!.name)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .accessibilityIdentifier("noScansMessage")
                    }
                    Spacer()
                } else {
                    ScrollView {
                        if scans.count > 1 {
                            // Dual carousels for top and bottom
                            HStack(spacing: 0) {
                                ImageCarousel(scans: scans, mole: appState.selectedMole, selectedIndex: $appState.selectedIndexTop)
                                    .accessibilityIdentifier("leftCarousel")
                                Divider()
                                ImageCarousel(scans: scans, mole: appState.selectedMole, selectedIndex: $appState.selectedIndexBottom)
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
                            
                            // The section containing the metric selection and the chart, which allows users to analyze the evolution of the mole's characteristics over time based on the available scans.
                            VStack (spacing: 2) {
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
                                
                                ChartView(mole: appState.selectedMole!, metric: appState.selectedMetric)
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
                            // If only one scan is available, just show a single carousel without the chart, since we can't show evolution with only one data point.
                            HStack(spacing: 0) {
                                Divider()
                                ImageCarousel(scans: scans, mole: appState.selectedMole, selectedIndex: $appState.selectedIndexBottom)
                            }
                        }
                    }
                }
            }
        }
    }

/**
    The selector bar at the top of the content view, which contains a picker for selecting a person and a menu for selecting a mole.
    The person picker allows users to choose from the list of people in the database, while the
    mole menu dynamically updates based on the selected person and allows users to select a specific mole to compare.
*/

    private var selectorBar: some View {
        HStack {
            Picker(
                "Person",
                selection: Binding(
                    get: { appState.selectedPerson },
                    set: { appState.selectPerson($0) }
                )
            ) {
                Text("Select Person").tag(nil as Person?)
                ForEach(people) { person in
                    Text(person.name).tag(person as Person?)
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("personPicker")

            if let person = appState.selectedPerson, !person.moles.isEmpty {
                Menu {
                    let grouped = Dictionary(grouping: person.moles, by: \.bodyPart)
                    ForEach(grouped.keys.sorted(), id: \.self) { bodyPart in
                        Section(bodyPart) {
                            ForEach(grouped[bodyPart]!) { mole in
                                Button {
                                    appState.selectMole(mole)
                                } label: {
                                    if appState.selectedMole == mole {
                                        Label(mole.name, systemImage: "checkmark")
                                    } else {
                                        Text(mole.name)
                                    }
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(appState.selectedMole?.name ?? "Select Mole")
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                    }
                    .foregroundColor(appState.selectedMole != nil ? .primary : .secondary)
                }
                .accessibilityIdentifier("molePicker")
            }
        }
        .padding(.horizontal)
        .accessibilityIdentifier("selectorBar")
    }
}

/// Preview provider for the CompareView, which sets up a preview environment with a shared data controller to allow for testing the UI in Xcode's canvas.
#Preview {
    CompareView()
        .modelContainer(DataController.shared.container)
}
