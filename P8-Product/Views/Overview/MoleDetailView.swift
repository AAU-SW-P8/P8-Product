//
// MoleDetailView.swift
// P8-Product
//

import SwiftUI

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
                        ImageCarousel(
                            scans: appState.scans,
                            mole: appState.activeMole,
                            selectedIndex: $appState.selectedIndex,
                            onDeleteSelectedInstance: {
                                appState.requestDeleteSelectedDetailInstance()
                            },
                            side: .both // Full circle for detail view
                        )
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
}

// MARK: - Custom Carousel Indicator Components

enum CarouselSide {
    case left
    case right
    case both
}

struct SelectionMarker: View {
    let side: CarouselSide
    var size: CGFloat = 12
    var color: Color = .accentColor

    var body: some View {
        switch side {
        case .left:
            Image(systemName: "square.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(color)
                .frame(width: size, height: size)

        case .right:
            Image(systemName: "triangle.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(color)
                .frame(width: size, height: size)

        case .both:
            Circle()
                .fill(color)
                .frame(width: size + 2, height: size + 2)
        }
    }
}
