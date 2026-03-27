//
// ImageCarousel.swift
// P8-Product
//

import SwiftUI

struct ImageCarousel: View {
    let scans: [MoleScan]
    @Binding var selectedIndex: Int
    var dotsOnLeft: Bool = false
    var height: CGFloat = 200

    private var safeIndex: Int {
        guard !scans.isEmpty else { return 0 }
        return min(selectedIndex, scans.count - 1)
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                if dotsOnLeft { dots }

                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(scans.enumerated()), id: \.element.id) { index, scan in
                            if let imageData = scan.imageData, let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .shadow(radius: 3)
                                    .padding(.horizontal, 8)
                                    .frame(height: height)
                                    .containerRelativeFrame(.vertical)
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
                                .frame(height: height)
                                .containerRelativeFrame(.vertical)
                                .id(index)
                            }
                        }
                    }
                    .scrollTargetLayout()
                }
                .frame(height: height)
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: Binding(
                    get: { safeIndex as Int? },
                    set: { newValue in
                        if let newValue { selectedIndex = newValue }
                    }
                ), anchor: .center)

                if !dotsOnLeft { dots }
            }

            Text(scans[safeIndex].captureDate, format: .dateTime.year().month().day().hour().minute())
                .font(.caption2)
        }
        .onChange(of: scans.count) {
            if selectedIndex >= scans.count {
                selectedIndex = max(0, scans.count - 1)
            }
        }
    }

    private var dots: some View {
        VStack(spacing: 6) {
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
        .padding(.horizontal, 4)
    }
}
