//
// MoleDetailView.swift
// P8-Product
//

import SwiftUI

struct MoleDetailView: View {
    let mole: Mole
    @State private var selectedIndex = 0
    @State private var showCompare = false
    @State private var didOpenEvolution = false
    @State private var selectionState = SelectionState.shared

    private var activeMole: Mole {
        selectionState.selectedMole ?? mole
    }

    private var scans: [MoleScan] {
        activeMole.instances
            .compactMap(\.moleScan)
            .sorted { $0.captureDate < $1.captureDate }
    }

    var body: some View {
        VStack(spacing: 0) {
            if scans.isEmpty {
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
                    ImageCarousel(scans: scans, mole: activeMole, selectedIndex: $selectedIndex)
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
        .navigationTitle(activeMole.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if scans.count > 1 {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Evolution") {
                        didOpenEvolution = true
                        selectionState.selectedPerson = activeMole.person
                        selectionState.selectedMole = activeMole
                        selectionState.pendingCompareMole = activeMole
                        showCompare = true
                    }
                    .accessibilityIdentifier("moleDetailCompareButton")
                }
            }
        }
        .navigationDestination(isPresented: $showCompare) {
            CompareView()
        }
        .onAppear {
            if !didOpenEvolution {
                selectionState.selectedMole = mole
            }
        }
        .onChange(of: scans.count) {
            if selectedIndex >= scans.count {
                selectedIndex = max(0, scans.count - 1)
            }
        }
    }
}
