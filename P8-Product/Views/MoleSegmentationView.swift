//
//  MoleSegmentationView.swift
//  P8-Product
//
//  Created by Simon Thordal on 3/24/26.
//

import SwiftUI
import SwiftData

/// A view that manually segments moles using SAM3 with the text prompt "moles".
///
/// Uses the pre-loaded SAM3 pipeline from SAM3ModelLoader
/// and runs segmentation on the test image upon user request. Detected mole regions
/// are shown as a semi-transparent red overlay on top of the original image.
struct MoleSegmentationTestView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Person.createdAt) private var people: [Person]

    // MARK: - State

    @State private var currentZoom = 0.0
    @State private var totalZoom = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    /// The image to segment. Replace with the image captured by the camera.
    @State private var testImage: UIImage? = UIImage(named: "test_mole_image")

    /// Combined mask overlay for all detected moles.
    @State private var maskOverlay: UIImage?
    
    /// Bounding boxes for each detected mole, in the original image's pixel coordinate space.
    @State private var detectedBoxes: [CGRect] = []

    /// `true` while models are loading or segmentation is running.
    @State private var isProcessing = false

    /// Status text shown beneath the image.
    @State private var statusMessage: String = "Ready"

    /// Holds the localised error message when something fails.
    @State private var errorMessage: String?

    /// Controls presentation of the error alert.
    @State private var showError = false

    /// Dynamic thresholds for segmentation.
    @State private var confidenceThreshold: Float = 0.3
    @State private var nmsThreshold: Float = 1.0

    /// Controls visibility of the settings controls.
    @State private var showSettings = false
    
    @State private var showPersonPicker = false
    @State private var selectedBoxForMole: CGRect?
    @State private var showingAddedMoleAlert = false

    /// Access the global SAM3 model loader
    @ObservedObject private var modelLoader = SAM3ModelLoader.shared

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                if let image = testImage {
                    imageContent(image: image)
                } else {
                    noImagePlaceholder
                }

                if isProcessing {
                    loadingOverlay
                }
            }
            .navigationTitle("Mole Segmentation")
            .toolbar { toolbarContent }
            .sheet(isPresented: $showSettings) {
                settingsSheet
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { showError = false }
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
            .confirmationDialog("Select Person", isPresented: $showPersonPicker, titleVisibility: .visible) {
                ForEach(people) { person in
                    Button(person.name) {
                        addMole(to: person, from: testImage, in: selectedBoxForMole)
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Success", isPresented: $showingAddedMoleAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Successfully added mole to overview.")
            }
        }
    }

    // MARK: - Image layer

    /// Renders the base image with the mask overlay composited on top.
    @ViewBuilder
    private func imageContent(image: UIImage) -> some View {
        GeometryReader { geometry in
            ZStack {
                if let mask = maskOverlay {
                    // Render the fully composited annotated image returned by MoleSegmentor
                    Image(uiImage: mask)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .overlay {
                            GeometryReader { imageGeo in
                                let imageAspect = mask.size.width / mask.size.height
                                let viewAspect = imageGeo.size.width / imageGeo.size.height
                                
                                let drawWidth = imageAspect > viewAspect ? imageGeo.size.width : imageGeo.size.height * imageAspect
                                let drawHeight = imageAspect > viewAspect ? imageGeo.size.width / imageAspect : imageGeo.size.height
                                
                                let drawX = (imageGeo.size.width - drawWidth) / 2
                                let drawY = (imageGeo.size.height - drawHeight) / 2
                                
                                let scaleX = drawWidth / mask.size.width
                                let scaleY = drawHeight / mask.size.height
                                
                                ForEach(0..<detectedBoxes.count, id: \.self) { index in
                                    let box = detectedBoxes[index]
                                    let rect = CGRect(
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
                                            selectedBoxForMole = box
                                            if people.isEmpty {
                                                errorMessage = "Please add a person in the Overview first."
                                                showError = true
                                            } else if people.count == 1 {
                                                addMole(to: people[0], from: testImage, in: box)
                                            } else {
                                                showPersonPicker = true
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
                Text(statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 2)
            }
        }
    }

    // MARK: - Actions

    /// Runs segmentation.
    @MainActor
    private func resegment() {
        guard let segmentor = modelLoader.segmentor, let image = testImage else { return }

        // These UI-related state changes are performed on the main actor.
        isProcessing = true
        statusMessage = "Segmenting…"
        // Don't clear cache if we're just re-segmenting the same image with different thresholds.
        // segmentor.clearCache() 

        // Run the model work off the main actor, then hop back to MainActor for UI updates.
        Task.detached {
            do {
                let result = try segmentor.segment(image: image, confidenceThreshold: self.confidenceThreshold, nmsThreshold: self.nmsThreshold)
                await MainActor.run {
                    self.maskOverlay = result?.0
                    self.detectedBoxes = result?.1 ?? []
                    self.statusMessage = result != nil ? "Segmentation complete. Long press a mole to add it." : "No moles detected"
                    self.isProcessing = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Segmentation failed: \(error.localizedDescription)"
                    self.showError = true
                    self.statusMessage = "Error"
                    self.isProcessing = false
                }
            }
        }
    }

    /// Removes the current mask overlay and clears the model's cache.
    @MainActor
    private func clearSegmentation() {
        maskOverlay = nil
        detectedBoxes = []
        statusMessage = "Cleared"
        modelLoader.segmentor?.clearCache()
    }
    
    private func addMole(to person: Person, from image: UIImage?, in box: CGRect?) {
        guard let image = image, let box = box else { return }
        
        // Add some padding around the mole for context
        let padding: CGFloat = 20.0
        var cropRect = box.insetBy(dx: -padding, dy: -padding)
        
        // Ensure cropRect stays within the image bounds
        let imageRect = CGRect(origin: .zero, size: image.size)
        cropRect = cropRect.intersection(imageRect)
        
        // Render the cropped image safely handling scale and orientation
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: cropRect.size, format: format)
        let croppedImage = renderer.image { _ in
            image.draw(at: CGPoint(x: -cropRect.origin.x, y: -cropRect.origin.y))
        }
        
        // Save scan and mole, similar to OverviewView
        let scan = MoleScan(imageData: croppedImage.jpegData(compressionQuality: 0.9))
        modelContext.insert(scan)
        
        let mole = Mole(
            name: "Mole \(person.moles.count + 1)",
            bodyPart: "Unassigned",
            isReminderActive: false,
            reminderFrequency: nil,
            nextDueDate: nil,
            person: person
        )
        modelContext.insert(mole)
        
        let instance = MoleInstance(
            diameter: 0,
            area: 0,
            mole: mole,
            moleScan: scan
        )
        modelContext.insert(instance)
        
        statusMessage = "Added mole to \(person.name)!"
        showingAddedMoleAlert = true
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
                            Text(String(format: "%.2f", confidenceThreshold))
                                .monospacedDigit()
                        }
                        Slider(value: $confidenceThreshold, in: 0.00...1.00, step: 0.05)
                    }
                    
                    VStack(alignment: .leading) {
                        HStack {
                            Text("NMS Overlap:")
                            Spacer()
                            Text(String(format: "%.2f", nmsThreshold))
                                .monospacedDigit()
                        }
                        Slider(value: $nmsThreshold, in: 0.00...1.00, step: 0.05)
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
                        showSettings = false
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
                Text(statusMessage)
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
                    showSettings = true
                } label: {
                    Label("Settings", systemImage: "slider.horizontal.3")
                }
                .disabled(modelLoader.segmentor == nil || isProcessing)

                Button("Segment") { resegment() }
                    .disabled(modelLoader.segmentor == nil || isProcessing)
                Button("Clear") { clearSegmentation() }
                    .disabled(maskOverlay == nil)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    MoleSegmentationTestView()
}