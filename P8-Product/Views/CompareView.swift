//
// CompareView.swift
// P8-Product
//

import SwiftUI
import SwiftData

public struct CompareView: View {
    @Query(sort: \Person.createdAt) private var people: [Person]

    @State private var appState = CompareAppState(dataController: .shared)

    public init() {}

    public var body: some View {
        CompareContentView (appState: appState, people: people)
    }
}


private struct CompareContentView: View {

    @Bindable var appState: CompareAppState
    var people: [Person]

    private var scans: [MoleScan] {
        guard let mole = appState.selectedMole else { return [] }
        return mole.instances
            .compactMap(\.moleScan)
            .sorted { $0.captureDate < $1.captureDate }
    }

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
                            HStack(spacing: 0) {
                                ImageCarousel(scans: scans, mole: appState.selectedMole, selectedIndex: $appState.selectedIndexTop)
                                    .accessibilityIdentifier("topCarousel")
                                Divider()
                                ImageCarousel(scans: scans, mole: appState.selectedMole, selectedIndex: $appState.selectedIndexBottom)
                                    .accessibilityIdentifier("bottomCarousel")
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


                            
                            ChartView(mole: appState.selectedMole, metric: appState.selectedMetric)
                            
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
                            HStack(spacing: 0) {
                                Divider()
                                ImageCarousel(scans: scans, mole: appState.selectedMole, selectedIndex: $appState.selectedIndexBottom)
                            }
                        }
                    }
                }
            }
        }
        .onChange(of: appState.selectedPerson) {
            appState.selectedMole = nil
            appState.selectedIndexTop = 0
            appState.selectedIndexBottom = 0
        }
        .onChange(of: appState.selectedMole) {
            appState.selectedIndexTop = 0
            appState.selectedIndexBottom = 0
        }
    }

    private var selectorBar: some View {
        HStack {
            Picker("Person", selection: $appState.selectedPerson) {
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
                                    appState.selectedMole = mole
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

#Preview {
    CompareView()
        .modelContainer(DataController.shared.container)
}
