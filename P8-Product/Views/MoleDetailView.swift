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
                
                Spacer()
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

                Spacer()
            }
        }
        .navigationTitle(appState.activeMole.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if appState.shouldShowEvolutionButton {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Evolution") { appState.openEvolution() }
                    .accessibilityIdentifier("moleDetailCompareButton")
                }
            }
        }
        .navigationDestination(isPresented: $appState.showCompare) {
            CompareView()
        }
        .onAppear {
            appState.handleAppear()
        }
        .onChange(of: appState.scans.count) {
            appState.clampSelectedIndexIfNeeded()
        }
    }
}
