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
        Self.safeIndex(for: scans, requested: selectedIndex)
    }

    private var selectedScan: MoleScan? {
        Self.selectedScan(in: scans, at: selectedIndex)
    }

    private var selectedInstance: MoleInstance? {
        Self.selectedInstance(in: scans, at: selectedIndex, for: mole)
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

    // MARK: - Selection helpers
    //
    // These are static and take their inputs explicitly so the unit tests in
    // PipelineTests can verify image-to-scan binding without having to render
    // the SwiftUI view. The instance-level computed properties above delegate
    // to these so the view's behaviour stays in lockstep with what is tested.

    static func safeIndex(for scans: [MoleScan], requested: Int) -> Int {
        guard !scans.isEmpty else { return 0 }
        return min(max(requested, 0), scans.count - 1)
    }

    static func selectedScan(in scans: [MoleScan], at index: Int) -> MoleScan? {
        guard !scans.isEmpty else { return nil }
        return scans[safeIndex(for: scans, requested: index)]
    }

    static func selectedInstance(in scans: [MoleScan], at index: Int, for mole: Mole?) -> MoleInstance? {
        guard let scan = selectedScan(in: scans, at: index) else { return nil }
        if let mole {
            return scan.instances.first(where: { $0.mole?.id == mole.id })
        }
        return scan.instances.first
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
