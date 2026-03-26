//
// ImageCarousel.swift
// P8-Product
//

import SwiftUI

struct ImageCarousel: View {
    let scans: [MoleScan]
    @Binding var selectedIndex: Int

    private var safeIndex: Int {
        min(selectedIndex, scans.count - 1)
    }

    var body: some View {
        TabView(selection: $selectedIndex) {
            ForEach(Array(scans.enumerated()), id: \.element.id) { index, scan in
                if let imageData = scan.imageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(radius: 5)
                        .padding(.horizontal, 24)
                        .tag(index)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.gray.opacity(0.2))
                        Image(systemName: "photo")
                            .font(.system(size: 48))
                            .foregroundColor(.gray.opacity(0.5))
                    }
                    .padding(.horizontal, 24)
                    .tag(index)
                }
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: 250)

        HStack(spacing: 8) {
            ForEach(scans.indices, id: \.self) { index in
                Circle()
                    .fill(index == safeIndex ? Color.primary : Color.gray.opacity(0.4))
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.top, 8)

        Text(scans[safeIndex].captureDate, format: .dateTime.year().month().day().hour().minute())
            .font(.headline)
            .padding(.top, 4)

        .onChange(of: scans.count) {
            if selectedIndex >= scans.count {
                selectedIndex = max(0, scans.count - 1)
            }
        }
    }
}
