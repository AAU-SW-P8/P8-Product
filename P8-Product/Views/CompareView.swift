//
// CompareView.swift
// P8-Product
//

import SwiftUI
import SwiftData

struct CompareView: View {
    @Query(sort: \HistoryItem.timestamp) private var items: [HistoryItem]
    @State private var selectedIndexTop = 0
    @State private var selectedIndexBottom = 0
    

    var body: some View {
        VStack(spacing: 0) {
            Text("Compare")
                .font(.largeTitle)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top)

            if items.isEmpty {
                Spacer()
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("No images yet")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
                Text("Capture some moles to compare them here.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                imageCarousel(selectedIndex: $selectedIndexTop)
                Divider()
                    .padding(.vertical, 4)
                imageCarousel(selectedIndex: $selectedIndexBottom)
            }
        }
        .onChange(of: items.count) {
            if selectedIndexTop >= items.count {
                selectedIndexTop = max(0, items.count - 1)
            }
            if selectedIndexBottom >= items.count {
                selectedIndexBottom = max(0, items.count - 1)
            }
        }
    }

    @ViewBuilder
    private func imageCarousel(selectedIndex: Binding<Int>) -> some View {
        TabView(selection: selectedIndex) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if let uiImage = item.image {
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
            ForEach(items.indices, id: \.self) { index in
                Circle()
                    .fill(index == selectedIndex.wrappedValue ? Color.primary : Color.gray.opacity(0.4))
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.top, 8)

        Text(items[selectedIndex.wrappedValue].timestamp, format: .dateTime.year().month().day().hour().minute())
            .font(.headline)
            .padding(.top, 4)

        if let person = items[selectedIndex.wrappedValue].person {
            Text(person.name)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.top, 2)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [HistoryItem.self, Person.self], inMemory: true)
}
