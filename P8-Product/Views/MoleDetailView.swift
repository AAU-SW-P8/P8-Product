//
// MoleDetailView.swift
// P8-Product
//

import SwiftUI

struct MoleDetailView: View {
    let mole: Mole
    @State private var selectedIndex = 0

    private var scans: [MoleScan] {
        mole.instances
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

                ImageCarousel(scans: scans, selectedIndex: $selectedIndex)
                    .fixedSize(horizontal: true, vertical: true)

                let safeIndex = min(selectedIndex, scans.count - 1)
                if let instance = mole.instances.first(where: { $0.moleScan == scans[safeIndex] }) {
                    VStack(spacing: 4) {
                        Text("Diameter: \(instance.diameter, specifier: "%.1f") mm")
                        Text("Area: \(instance.area, specifier: "%.1f") mm²")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
                }

                Spacer()
            }
        }
        .navigationTitle(mole.name)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: scans.count) {
            if selectedIndex >= scans.count {
                selectedIndex = max(0, scans.count - 1)
            }
        }
    }
}
