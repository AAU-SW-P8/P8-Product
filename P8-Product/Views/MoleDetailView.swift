//
// MoleDetailView.swift
// P8-Product
//

import SwiftUI

struct MoleDetailView: View {
    @State private var appState: MoleDetailAppState

    init(mole: Mole) {
        _appState = State(initialValue: MoleDetailAppState(mole: mole))
    }

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
                    HStack(spacing: 0) {
                        ImageCarousel(scans: appState.scans, mole: appState.activeMole, selectedIndex: $appState.selectedIndex)
                            .frame(maxWidth: 420)
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
                    Spacer()
                }
            } else {
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
                        if appState.scans.count > 1 {
                            HStack(spacing: 0) {
                                ImageCarousel(scans: appState.scans, mole: appState.activeMole, selectedIndex: $appState.selectedEvolutionTopIndex)
                                    .accessibilityIdentifier("leftCarousel")
                                Divider()
                                ImageCarousel(scans: appState.scans, mole: appState.activeMole, selectedIndex: $appState.selectedEvolutionBottomIndex)
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

                                ChartView(mole: appState.activeMole, metric: appState.selectedMetric)
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
                                ImageCarousel(scans: appState.scans, mole: appState.activeMole, selectedIndex: $appState.selectedEvolutionBottomIndex)
                                    .frame(maxWidth: 420)
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
        .navigationTitle(appState.activeMole.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            appState.handleAppear()
        }
        .onChange(of: appState.scans.count) {
            appState.clampSelectedIndicesIfNeeded()
        }
    }
}
