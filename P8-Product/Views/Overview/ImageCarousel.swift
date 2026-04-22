//
// ImageCarousel.swift
// P8-Product
//

import SwiftUI

/**
 A horizontally scrollable carousel of mole scan images, with pagination dots and metadata display.

 This view takes an array of `MoleScan` objects and displays their images in a paginated scroll view. The user can swipe left or right to navigate through the scans, and the currently selected scan's capture date and instance measurements are shown below the carousel. Tapping on a pagination dot will animate the carousel to the corresponding scan.

 The view also includes logic to ensure that the selected index remains valid if the number of scans changes, and it provides static helper methods for determining the safe index and selected scan/instance based on the current state.

 - Fields:
    - scans: An array of `MoleScan` objects to display.
    - mole: An optional `Mole` object to filter the displayed instances.
    - selectedIndex: A binding to the currently selected index.
    - height: The height of the carousel images.
 */
struct ImageCarousel: View {
    let scans: [MoleScan]
    var mole: Mole? = nil
    @Binding var selectedIndex: Int
    @State private var scrollPositionID: UUID?
    var onDeleteSelectedInstance: (() -> Void)? = nil
    var height: CGFloat = 200

    var side: CarouselSide = .both
    var otherSelectedIndex: Int? = nil

    private var safeIndex: Int {
        Self.safeIndex(for: scans, requested: selectedIndex)
    }

    private var selectedScan: MoleScan? {
        Self.selectedScan(in: scans, at: selectedIndex)
    }

    private var selectedInstance: MoleInstance? {
        Self.selectedInstance(in: scans, at: selectedIndex, for: mole)
    }

    private var displayedScans: [(displayIndex: Int, originalIndex: Int, scan: MoleScan)] {
        let indexed = Array(scans.enumerated()).map { (originalIndex: $0.offset, scan: $0.element) }
        let ordered = (side == .left || side == .right) ? Array(indexed.reversed()) : indexed

        return Array(ordered.enumerated()).map { offset, element in
            (
                displayIndex: offset,
                originalIndex: element.originalIndex,
                scan: element.scan
            )
        }
    }

    private var selectedScanID: UUID? {
        guard !scans.isEmpty else { return nil }
        return scans[safeIndex].id
    }

    var body: some View {
        VStack(spacing: 4) {
            carouselSection
            dots
            selectedInfoSection
        }
        .accessibilityElement(children: .contain)
        .onChange(of: scans.count) {
            if selectedIndex >= scans.count {
                selectedIndex = max(0, scans.count - 1)
            }
            scrollPositionID = selectedScanID
        }
        .onAppear {
            scrollPositionID = selectedScanID
        }
        .onChange(of: selectedScanID) { _, newValue in
            guard scrollPositionID != newValue else { return }
            scrollPositionID = newValue
        }
    }

    private var carouselSection: some View {
        GeometryReader { geometry in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 0) {
                    ForEach(displayedScans, id: \.scan.id) { item in
                        carouselImageView(for: item, width: geometry.size.width)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(
                id: Binding(
                    get: { scrollPositionID },
                    set: { newValue in
                        guard let newValue,
                              let newIndex = scans.firstIndex(where: { $0.id == newValue })
                        else { return }

                        scrollPositionID = newValue
                        selectedIndex = newIndex
                    }
                ),
                anchor: .center
            )
        }
        .frame(height: height)
    }

    @ViewBuilder
    private func carouselImageView(
        for item: (displayIndex: Int, originalIndex: Int, scan: MoleScan),
        width: CGFloat
    ) -> some View {
        if let imageData = item.scan.imageData,
           let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(radius: 3)
                .padding(.horizontal, 8)
                .frame(width: width, height: height)
                .id(item.scan.id)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))

                Image(systemName: "photo")
                    .font(.system(size: 28))
                    .foregroundColor(.gray.opacity(0.5))
            }
            .padding(.horizontal, 8)
            .frame(width: width, height: height)
            .id(item.scan.id)
        }
    }

    @ViewBuilder
    private var selectedInfoSection: some View {
        if let selectedScan = selectedScan {
            Text(selectedScan.captureDate, format: .dateTime.year().month().day().hour().minute())
                .font(.caption2)

            if let selectedInstance = selectedInstance {
                HStack {
                    Color.clear
                        .frame(width: 28, height: 1)

                    Spacer()

                    VStack(spacing: 2) {
                        Text("Diameter: \(Double(selectedInstance.diameter), specifier: "%.1f") mm")
                        Text("Area: \(Double(selectedInstance.area), specifier: "%.1f") mm²")
                    }
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                    Spacer()

                    if let onDeleteSelectedInstance {
                        Button(role: .destructive, action: onDeleteSelectedInstance) {
                            Image(systemName: "trash")
                        }
                        .frame(width: 28)
                        .accessibilityIdentifier("deleteMoleInstanceButton")
                    } else {
                        Color.clear
                            .frame(width: 28, height: 1)
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Selection helpers

    /**
        Returns a safe index within the bounds of the scans array. 
        If the requested index is out of bounds, it will return the nearest valid index (0 or scans.count - 1).
        Parameters:
        - scans: The array of MoleScan objects to check against.
        - requested: The index that is being requested for selection.
     */
    static func safeIndex(for scans: [MoleScan], requested: Int) -> Int {
        guard !scans.isEmpty else { return 0 }
        return min(max(requested, 0), scans.count - 1)
    }

    /**
        Returns the MoleScan object corresponding to the given index, using safeIndex to ensure it's within bounds.
        Parameters:
        - scans: The array of MoleScan objects to select from.
        - index: The requested index for selection.
     */
    static func selectedScan(in scans: [MoleScan], at index: Int) -> MoleScan? {
        guard !scans.isEmpty else { return nil }
        return scans[safeIndex(for: scans, requested: index)]
    }

    /**
        Returns the MoleInstance corresponding to the given index and mole filter, using selectedScan to find the correct scan first.
        If a mole is provided, it will return the instance matching that mole's ID. 
        If no mole is provided, it will return the first instance in the selected scan.
        Parameters:
        - scans: The array of MoleScan objects to search through.
        - index: The requested index for selection.
        - mole: An optional Mole object to filter the instances by.
     */
    static func selectedInstance(in scans: [MoleScan], at index: Int, for mole: Mole?) -> MoleInstance? {
        guard let scan = selectedScan(in: scans, at: index) else { return nil }

        if let mole {
            return scan.instances.first(where: { $0.mole?.id == mole.id })
        }

        return scan.instances.first
    }

    enum DotItem: Hashable {
        case index(Int)
        case ellipsis(String)
    }

    private var safeOtherSelectedIndex: Int? {
        guard let otherSelectedIndex, !scans.isEmpty else { return nil }
        return Self.safeIndex(for: scans, requested: otherSelectedIndex)
    }

    // 2. Delegate the property to your new static testable function
    private var visibleDotItems: [DotItem] {
        Self.calculateDotItems(count: scans.count, safeIndex: safeIndex, side: side)
    }

    // 3. Add this pure function to your Selection helpers
    static func calculateDotItems(count: Int, safeIndex: Int, side: CarouselSide) -> [DotItem] {
        guard count > 0 else { return [] }
        
        let items: [DotItem]
        
        if count <= 5 {
            items = (0..<count).map { .index($0) }
        } else {
            let last = count - 1

            // Beginning
            if safeIndex <= 2 {
                items = [.index(0), .index(1), .index(2), .ellipsis("right"), .index(last)]
            }
            // End
            else if safeIndex >= last - 2 {
                items = [.index(0), .ellipsis("left"), .index(last - 2), .index(last - 1), .index(last)]
            }
            // Middle
            else {
                items = [.index(0), .ellipsis("left"), .index(safeIndex - 1), .index(safeIndex), .index(safeIndex + 1), .ellipsis("right"), .index(last)]
            }
        }
        
        return (side == .left || side == .right) ? items.reversed() : items
    }

    /**
        Renders the carousel's pagination indicators for the currently visible set of scans.
        This view displays a tappable dot for each visible page index and an ellipsis indicator when
        not all pages are shown at once. Tapping a dot animates the carousel selection to that index.
    */
    private var dots: some View {
        HStack(spacing: 8) {
            ForEach(visibleDotItems, id: \.self) { item in
                switch item {
                case .index(let index):
                    dotView(for: index)
                        .onTapGesture {
                            withAnimation {
                                selectedIndex = index
                            }
                        }

                case .ellipsis:
                    HStack(spacing: 2) {
                        Circle().fill(Color.gray.opacity(0.4)).frame(width: 3, height: 3)
                        Circle().fill(Color.gray.opacity(0.4)).frame(width: 3, height: 3)
                        Circle().fill(Color.gray.opacity(0.4)).frame(width: 3, height: 3)
                    }
                    .frame(minWidth: 14, minHeight: 14)
                }
            }
        }
        .padding(.top, 4)
    }

    /**
        Returns a safe index within the bounds of the scans array. 
        If the requested index is out of bounds, it will return the nearest valid index (0 or scans.count - 1).
        Parameters:
        - scans: The array of MoleScan objects to check against.
        - requested: The index that is being requested for selection.
     */
    @ViewBuilder
    private func dotView(for index: Int) -> some View {
        let isActive = index == safeIndex
        let isOtherActive = index == safeOtherSelectedIndex

        ZStack {
            if isActive && isOtherActive {
                Circle()
                    .fill(Color.primary)
                    .frame(width: 10, height: 10)
            } else if isActive {
                indicatorShape(for: side, isPrimary: true)
            } else if isOtherActive {
                let otherSide: CarouselSide = (side == .left) ? .right : .left
                indicatorShape(for: otherSide, isPrimary: false)
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.4))
                    .frame(width: 6, height: 6)
            }
        }
        .frame(width: 14, height: 14)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: safeIndex)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: safeOtherSelectedIndex)
    }

    /**
        Determines the appropriate shape and color for the pagination dot indicators based on which carousel is selecting the corresponding data point. 
        The primary selected carousel will have a more prominent shape and color, while the other carousel (if also selecting the same index) will have a subtler appearance.
        Parameters:
        - carouselSide: The side of the carousel (left, right, or both) that is currently selecting the data point.
        - isPrimary: A boolean indicating whether this carousel is the primary one selecting the data point (true) or if it's the secondary one when both carousels select the same index (false).
     */
    @ViewBuilder
    private func indicatorShape(for carouselSide: CarouselSide, isPrimary: Bool) -> some View {
        let color: Color = isPrimary ? .primary : .gray.opacity(0.4)
        let size: CGFloat = isPrimary ? 10 : 8

        switch carouselSide {
        case .left:
            Image(systemName: "square.fill")
                .resizable()
                .foregroundColor(color)
                .frame(width: size, height: size)

        case .right:
            Image(systemName: "triangle.fill")
                .resizable()
                .foregroundColor(color)
                .frame(width: size, height: size)

        case .both:
            Circle()
                .fill(color)
                .frame(width: size, height: size)
        }
    }
}

enum CarouselSide {
    case left
    case right
    case both
}
