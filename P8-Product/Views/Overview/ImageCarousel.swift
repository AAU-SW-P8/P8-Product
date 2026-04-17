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
        - scans: An array of `MoleScan` objects to display in the carousel.
        - mole: An optional `Mole` object to filter the displayed instances. If nil, the first instance of each scan will be shown.
        - selectedIndex: A binding to the currently selected index in the carousel, which will update as the user scrolls or taps on pagination dots.
        - height: The height of the carousel images, defaulting to 200 points.
*/
struct ImageCarousel: View {
    let scans: [MoleScan]
    var mole: Mole? = nil
    @Binding var selectedIndex: Int
    @State private var scrollPositionID: UUID?
    var onDeleteSelectedInstance: (() -> Void)? = nil
    var height: CGFloat = 200
    
    // Add this right below your existing properties
    var side: CarouselSide = .both
    var otherSelectedIndex: Int? = nil // <-- NEW
    /// The safe index to use for display, ensuring it stays within bounds of the scans array.
    private var safeIndex: Int {
        Self.safeIndex(for: scans, requested: selectedIndex)
    }
    /// The currently selected scan based on the safe index, or nil if there are no scans.
    private var selectedScan: MoleScan? {
        Self.selectedScan(in: scans, at: selectedIndex)
    }
    /// The currently selected instance based on the selected scan and optional mole filter, or nil if no scan is selected or no instance matches.
    private var selectedInstance: MoleInstance? {
        Self.selectedInstance(in: scans, at: selectedIndex, for: mole)
    }
    
    private var displayedScans: [(displayIndex: Int, originalIndex: Int, scan: MoleScan)] {
        let indexed = Array(scans.enumerated()).map { (originalIndex: $0.offset, scan: $0.element) }
        
        // Change from 'side == .right' so both sides share the mirrored timeline
        let ordered = (side == .left || side == .right) ? Array(indexed.reversed()) : indexed

        return Array(ordered.enumerated()).map { offset, element in
            (
                displayIndex: offset,
                originalIndex: element.originalIndex,
                scan: element.scan
            )
        }
    }

    private var displayedSelectedIndex: Int {
        guard !scans.isEmpty else { return 0 }
        
        // Change from 'side == .right' to match the updated array logic above
        return (side == .left || side == .right) ? (scans.count - 1 - safeIndex) : safeIndex
    }

    /// Stable identity of the currently selected scan for ScrollView paging.
    private var selectedScanID: UUID? {
        guard !scans.isEmpty else { return nil }
        return scans[safeIndex].id
    }

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geometry in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 0) {
                        ForEach(displayedScans, id: \.scan.id) { item in
                            if let imageData = item.scan.imageData,
                               let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .shadow(radius: 3)
                                    .padding(.horizontal, 8)
                                    .frame(width: geometry.size.width, height: height)
                                    .id(scan.id)
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
                                .id(scan.id)
                            }
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: Binding(
                    get: { scrollPositionID },
                    set: { newValue in
                        guard let newValue else { return }
                        guard let newIndex = scans.firstIndex(where: { $0.id == newValue }) else { return }
                        scrollPositionID = newValue
                        selectedIndex = newIndex
                    }
                ), anchor: .center)
            }
            .frame(height: height)

            dots

            if let selectedScan {
                Text(selectedScan.captureDate, format: .dateTime.year().month().day().hour().minute())
                    .font(.caption2)

                if let selectedInstance {
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

    // MARK: - Selection helpers
    //
    // These are static and take their inputs explicitly so the unit tests in
    // PipelineTests can verify image-to-scan binding without having to render
    // the SwiftUI view. The instance-level computed properties above delegate
    // to these so the view's behaviour stays in lockstep with what is tested.

    /**
     Returns a safe index for the given scans array and requested index, ensuring it stays within bounds.
     
     - Parameters:
        - scans: The array of `MoleScan` objects to consider.
        - requested: The requested index to validate.
     - Returns: A valid index that is at least 0 and at most `scans.count - 1`. If `scans` is empty, returns 0.
     */

    static func safeIndex(for scans: [MoleScan], requested: Int) -> Int {
        guard !scans.isEmpty else { return 0 }
        return min(max(requested, 0), scans.count - 1)
    }

    /**
     Returns the selected `MoleScan` based on the given scans array and index, using the safe index logic.
     
     - Parameters:
        - scans: The array of `MoleScan` objects to consider.
        - index: The requested index to select.
     - Returns: The `MoleScan` at the safe index, or nil if `scans` is empty.
     */
    static func selectedScan(in scans: [MoleScan], at index: Int) -> MoleScan? {
        guard !scans.isEmpty else { return nil }
        return scans[safeIndex(for: scans, requested: index)]
    }
    /**
     Returns the selected `MoleInstance` based on the given scans array, index, and optional mole filter.
     
     - Parameters:
        - scans: The array of `MoleScan` objects to consider.
        - index: The requested index to select the scan from.
        - mole: An optional `Mole` object to filter the instances. If nil, the first instance of the selected scan will be returned.
     - Returns: The `MoleInstance` that matches the criteria, or nil if no scan is selected or no instance matches.
     */
    static func selectedInstance(in scans: [MoleScan], at index: Int, for mole: Mole?) -> MoleInstance? {
        guard let scan = selectedScan(in: scans, at: index) else { return nil }
        if let mole {
            return scan.instances.first(where: { $0.mole?.id == mole.id })
        }
        return scan.instances.first
    }
    private enum DotItem: Hashable {
        case index(Int)
        case ellipsis(String)
    }

    private var safeOtherSelectedIndex: Int? {
        guard let otherSelectedIndex, !scans.isEmpty else { return nil }
        return Self.safeIndex(for: scans, requested: otherSelectedIndex)
    }

    private var visibleDotItems: [DotItem] {
        let count = scans.count
        let items: [DotItem]
        
        if count <= 5 {
            items = scans.indices.map { .index($0) }
        } else {
            let last = count - 1

            // Beginning: show first 3, then ..., then last
            if safeIndex <= 2 {
                items = [
                    .index(0),
                    .index(1),
                    .index(2),
                    .ellipsis("right"),
                    .index(last)
                ]
            }
            // End: show first, then ..., then last 3
            else if safeIndex >= last - 2 {
                items = [
                    .index(0),
                    .ellipsis("left"),
                    .index(last - 2),
                    .index(last - 1),
                    .index(last)
                ]
            }
            // Middle: show first, ..., current-1/current/current+1, ..., last
            else {
                items = [
                    .index(0),
                    .ellipsis("left"),
                    .index(safeIndex - 1),
                    .index(safeIndex),
                    .index(safeIndex + 1),
                    .ellipsis("right"),
                    .index(last)
                ]
            }
        }
        
        // Reverse the dots for the side-by-side evolution views so they match the scroll direction
        return (side == .left || side == .right) ? items.reversed() : items
    }
    
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

        // Helper function to draw the correct shape based on the side
        @ViewBuilder
        private func indicatorShape(for carouselSide: CarouselSide, isPrimary: Bool) -> some View {
            let color: Color = isPrimary ? .primary : .gray.opacity(0.4)
            let size: CGFloat = isPrimary ? 10 : 8 // Ghost shape is slightly smaller
            
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

