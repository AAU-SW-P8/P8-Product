//
//  MoleSegmentationView.swift
//  P8-Product
//
//  Created by Simon Thordal on 3/24/26.
//
import SwiftUI
import SwiftData

struct MoleSegmentationTestView: View {
    @Query(sort: \Person.createdAt)
    private var people: [Person]
    @State private var AppState: MoleSegmentationAppState = MoleSegmentationAppState(dataController: .shared)

    // MARK: - UI-Only State (Gestures)
    @State private var currentZoom: Double = 0.0
    @State private var totalZoom: Double = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        NavigationStack {
            ZStack {
                if let image: UIImage = AppState.testImage {
                    imageContent(image: image)
                } else {
                    noImagePlaceholder
                }

                if AppState.isProcessing {
                    loadingOverlay
                }
            }
            .navigationTitle("Mole Segmentation")
            .toolbar { toolbarContent }
            .sheet(isPresented: $AppState.showSettings) {
                // Assuming settingsSheet is extracted
                settingsSheet
            }
            .confirmationDialog("Who is this scan for?", isPresented: $AppState.showPersonPicker) {
                ForEach(people) { person in
                    Button(person.name) {
                        AppState.selectedPersonForScan = person
                        AppState.resegment()
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog("Mole Action", isPresented: $AppState.showMoleActionDialog) {
                Button("New Mole") { AppState.handleNewMoleSelection() }
                if let person: Person = AppState.selectedPersonForScan, !person.moles.isEmpty {
                    Button("Existing Mole") { AppState.showExistingMolePicker = true }
                }
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog("Select Existing Mole", isPresented: $AppState.showExistingMolePicker) {
                if let person: Person = AppState.selectedPersonForScan {
                    ForEach(person.moles) { mole in
                        Button(mole.name) { AppState.handleExistingMoleSelection(mole: mole) }
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .alert(item: $AppState.activeAlert) { alert in
                Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("OK")))
            }
        }
    }

    // MARK: - Image layer

    /// Renders the base image with the mask overlay composited on top.
    @ViewBuilder
    private func imageContent(image: UIImage) -> some View {
        GeometryReader { geometry in
            ZStack {
                if let mask: UIImage = AppState.maskOverlay {
                    // Render the fully composited annotated image returned by MoleSegmentor
                    Image(uiImage: mask)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .overlay {
                            GeometryReader { imageGeo in
                                let imageAspect: Double = mask.size.width / mask.size.height
                                let viewAspect: Double = imageGeo.size.width / imageGeo.size.height

                                let drawWidth: Double = imageAspect > viewAspect ? imageGeo.size.width : imageGeo.size.height * imageAspect
                                let drawHeight: Double = imageAspect > viewAspect ? imageGeo.size.width / imageAspect : imageGeo.size.height

                                let drawX: Double = (imageGeo.size.width - drawWidth) / 2
                                let drawY: Double = (imageGeo.size.height - drawHeight) / 2

                                let scaleX: Double = drawWidth / mask.size.width
                                let scaleY: Double = drawHeight / mask.size.height

                                ForEach(0..<AppState.detectedBoxes.count, id: \.self) { index in
                                    let box: CGRect = AppState.detectedBoxes[index]
                                    let rect: CGRect = CGRect(
                                        x: drawX + box.minX * scaleX,
                                        y: drawY + box.minY * scaleY,
                                        width: box.width * scaleX,
                                        height: box.height * scaleY
                                    )
                                    
                                    Rectangle()
                                        .fill(Color.clear)
                                        .contentShape(Rectangle())
                                        .frame(width: rect.width, height: rect.height)
                                        .position(x: rect.midX, y: rect.midY)
                                        .onLongPressGesture {
                                            AppState.selectedBoxForMole = box
                                            if AppState.selectedPersonForScan == nil && people.count == 1 {
                                                AppState.selectedPersonForScan = people[0]
                                            }
                                            
                                            if AppState.selectedPersonForScan != nil {
                                                AppState.showMoleActionDialog = true
                                            } else {
                                                AppState.activeAlert = .error("Please segment again to select a person.")
                                            }
                                        }
                                }
                            }
                        }
                } else {
                    // Fallback: show the original image before segmentation completes
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }
            }
            .offset(x: offset.width + lastOffset.width, y: offset.height + lastOffset.height)
            .scaleEffect(totalZoom + currentZoom)
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        currentZoom = value - 1
                    }
                    .onEnded { value in
                        totalZoom += currentZoom
                        currentZoom = 0
                        
                        if totalZoom < 1.0 {
                            withAnimation {
                                totalZoom = 1.0
                                offset = .zero
                                lastOffset = .zero
                            }
                        } else if totalZoom > 5.0 {
                            withAnimation {
                                totalZoom = 5.0
                            }
                        }
                    }
            )
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        if totalZoom + currentZoom > 1.0 {
                            offset = value.translation
                        }
                    }
                    .onEnded { value in
                        if totalZoom + currentZoom > 1.0 {
                            lastOffset.width += offset.width
                            lastOffset.height += offset.height
                            offset = .zero
                        }
                    }
            )
        }
        .safeAreaInset(edge: .bottom) {
            VStack {
                Text(AppState.statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 2)
            }
        }
    }

    // MARK: - Supporting views

    /// A sheet containing controls for confidence and NMS thresholds.
    private var settingsSheet: some View {
        NavigationStack {
            List {
                Section("Detection Thresholds") {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Confidence:")
                            Spacer()
                            Text(String(format: "%.2f", AppState.confidenceThreshold))
                                .monospacedDigit()
                        }
                        Slider(value: $AppState.confidenceThreshold, in: 0.00...1.00, step: 0.05)
                    }
                    
                    VStack(alignment: .leading) {
                        HStack {
                            Text("NMS Overlap:")
                            Spacer()
                            Text(String(format: "%.2f", AppState.nmsThreshold))
                                .monospacedDigit()
                        }
                        Slider(value: $AppState.nmsThreshold, in: 0.00...1.00, step: 0.05)
                        Text("Higher values allow more overlapping boxes.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Parameters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        AppState.showSettings = false
                    }
                }
            }
            .presentationDetents([.height(300)])
        }
    }

    /// Full-screen overlay shown while loading or segmenting.
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView().scaleEffect(1.5)
                Text(AppState.statusMessage)
                    .foregroundStyle(.white)
                    .font(.headline)
            }
            .padding()
            .background(.black.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    /// Shown in place of the image when `testImage` is `nil`.
    private var noImagePlaceholder: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("No test image found")
                .font(.headline)
            Text("Add an image named 'test_mole_image' to Assets.xcassets")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding()
        }
    }

    /// Navigation bar buttons.
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack {
                Button {
                    AppState.showSettings = true
                } label: {
                    Label("Settings", systemImage: "slider.horizontal.3")
                }
                .disabled(AppState.isProcessing)

                Button("Segment") { AppState.startSegmentationFlow(people: people) }
                    .disabled(AppState.isProcessing)
                Button("Clear") { AppState.clearSegmentation() }
                    .disabled(AppState.maskOverlay == nil)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    MoleSegmentationTestView()
}
