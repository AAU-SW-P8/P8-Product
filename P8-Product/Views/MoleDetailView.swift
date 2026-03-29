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

                ImageCarousel(scans: scans, mole: mole, selectedIndex: $selectedIndex)
                    .fixedSize(horizontal: true, vertical: true)

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
