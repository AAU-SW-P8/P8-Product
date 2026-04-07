//
// ImageCarousel.swift
// P8-Product
//

import SwiftUI

struct ImageCarousel: View {
    let scans: [MoleScan]
    var mole: Mole? = nil
    @Binding var selectedIndex: Int
    var height: CGFloat = 200

    private var safeIndex: Int {
        guard !scans.isEmpty else { return 0 }
        return min(selectedIndex, scans.count - 1)
    }

    private var selectedScan: MoleScan? {
        guard !scans.isEmpty else { return nil }
        return scans[safeIndex]
    }

    private var selectedInstance: MoleInstance? {
        guard let selectedScan else { return nil }
        if let selectedMole = mole {
            return selectedScan.instances.first(where: { $0.mole?.id == selectedMole.id })
        }
        return selectedScan.instances.first
    }

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geometry in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 0) {
                        ForEach(Array(scans.enumerated()), id: \.element.id) { index, scan in
                            if let imageData = scan.imageData, let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .shadow(radius: 3)
                                    .padding(.horizontal, 8)
                                    .frame(width: geometry.size.width, height: height)
                                    .id(index)
                            } else {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.gray.opacity(0.2))
                                    Image(systemName: "photo")
                                        .font(.system(size: 28))
                                        .foregroundColor(.gray.opacity(0.5))
                                }
                                .padding(.horizontal, 8)
                                .frame(width: geometry.size.width, height: height)
                                .id(index)
                            }
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: Binding(
                    get: { safeIndex as Int? },
                    set: { newValue in
                        if let newValue { selectedIndex = newValue }
                    }
                ), anchor: .center)
            }
            .frame(height: height)

            dots

            if let selectedScan {
                Text(selectedScan.captureDate, format: .dateTime.year().month().day().hour().minute())
                    .font(.caption2)

                if let selectedInstance {
                    VStack(spacing: 2) {
                        Text("Diameter: \(selectedInstance.diameter, specifier: "%.1f") mm")
                        Text("Area: \(selectedInstance.area, specifier: "%.1f") mm²")
                    }
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .onChange(of: scans.count) {
            if selectedIndex >= scans.count {
                selectedIndex = max(0, scans.count - 1)
            }
        }
    }

    private var dots: some View {
        HStack(spacing: 6) {
            ForEach(scans.indices, id: \.self) { index in
                Circle()
                    .fill(index == safeIndex ? Color.primary : Color.gray.opacity(0.4))
                    .frame(width: 6, height: 6)
                    .onTapGesture {
                        withAnimation {
                            selectedIndex = index
                        }
                    }
            }
        }
        .padding(.top, 4)
    }
}
