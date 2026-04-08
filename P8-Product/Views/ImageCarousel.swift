//
// ImageCarousel.swift
// P8-Product
//

import SwiftUI


/**
    A horizontally scrollable carousel of mole scan images, with pagination dots and metadata display.
    
    This view takes an array of `MoleScan` objects and displays their images in a paginated scroll view. The user can swipe left or right to navigate through the scans, and the currently selected scan's capture date and instance measurements are shown below the carousel. Tapping on a pagination dot will animate the carousel to the corresponding scan.
    
    The view also includes logic to ensure that the selected index remains valid if the number of scans changes, and it provides static helper methods for determining the safe index and selected scan/instance based on the current state.

    - Parameters:
        - scans: An array of `MoleScan` objects to display in the carousel.
        - mole: An optional `Mole` object to filter the displayed instances. If nil, the first instance of each scan will be shown.
        - selectedIndex: A binding to the currently selected index in the carousel, which will update as the user scrolls or taps on pagination dots.
        - height: The height of the carousel images, defaulting to 200 points.
*/
struct ImageCarousel: View {
    let scans: [MoleScan]
    var mole: Mole? = nil
    @Binding var selectedIndex: Int
    var height: CGFloat = 200
    /// The safe index to use for display, ensuring it stays within bounds of the scans array.
    private var safeIndex: Int {
        Self.safeIndex(for: scans, requested: selectedIndex)
    }
    /// The currently selected scan based on the safe index, or nil if there are no scans.
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
