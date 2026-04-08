//
// CompareView.swift
// P8-Product
//

import SwiftUI
import SwiftData

struct CompareView: View {
    @Query(sort: \Person.createdAt) private var people: [Person]

    @State private var selectedPerson: Person?
    @State private var selectedMole: Mole?
    @State private var selectedMetric: ChartMetric = .area
    @State private var selectedIndexTop = 0
    @State private var selectedIndexBottom = 0

    private var scans: [MoleScan] {
        guard let mole = selectedMole else { return [] }
        return mole.instances
            .compactMap(\.moleScan)
            .sorted { $0.captureDate < $1.captureDate }
    }

    private var selectedPersonHasAnyScans: Bool {
        guard let selectedPerson else { return false }
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
                    if selectedPerson == nil {
                        Text("Select a person")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .accessibilityIdentifier("selectPersonPrompt")
                    } 
                    else if !selectedPersonHasAnyScans {
                        Text("You haven't captured any moles for \(selectedPerson!.name) yet")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .accessibilityIdentifier("makeScanBeforeCompareMessage")
                    } else if selectedMole == nil {
                        Text("Select a mole")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .accessibilityIdentifier("selectMolePrompt")
                    } else {
                        Text("No scans for \(selectedMole!.name)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .accessibilityIdentifier("noScansMessage")
                    }
                    Spacer()
                } else {
                    ScrollView {
                        if scans.count > 1 {
                            HStack(spacing: 0) {
                                ImageCarousel(scans: scans, mole: selectedMole, selectedIndex: $selectedIndexTop)
                                    .accessibilityIdentifier("topCarousel")
                                Divider()
                                ImageCarousel(scans: scans, mole: selectedMole, selectedIndex: $selectedIndexBottom)
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
                            Picker("Metric", selection: $selectedMetric) {
                                ForEach(ChartMetric.allCases) { metric in
                                    Text(metric.title).tag(metric)
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding(.horizontal)
                            .padding(.top, 8)
                            .accessibilityIdentifier("metricPicker")


                            if let selectedMole {
                                ChartView(mole: selectedMole, metric: selectedMetric)
                            }
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
                                //ImageCarousel(scans: scans, selectedIndex: $selectedIndexTop)
                                Divider()
                                ImageCarousel(scans: scans, mole: selectedMole, selectedIndex: $selectedIndexBottom)
                            }
                        }
                    }
                }
            }
        }
        .onChange(of: selectedPerson) {
            selectedMole = nil
            selectedIndexTop = 0
            selectedIndexBottom = 0
        }
        .onChange(of: selectedMole) {
            selectedIndexTop = 0
            selectedIndexBottom = 0
        }
    }

    private var selectorBar: some View {
        HStack {
            Picker("Person", selection: $selectedPerson) {
                Text("Select Person").tag(nil as Person?)
                ForEach(people) { person in
                    Text(person.name).tag(person as Person?)
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("personPicker")

            if let person = selectedPerson, !person.moles.isEmpty {
                Menu {
                    let grouped = Dictionary(grouping: person.moles, by: \.bodyPart)
                    ForEach(grouped.keys.sorted(), id: \.self) { bodyPart in
                        Section(bodyPart) {
                            ForEach(grouped[bodyPart]!) { mole in
                                Button {
                                    selectedMole = mole
                                } label: {
                                    if selectedMole == mole {
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
                        Text(selectedMole?.name ?? "Select Mole")
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                    }
                    .foregroundColor(selectedMole != nil ? .primary : .secondary)
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
