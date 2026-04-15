//
//  MoleSegmentationView.swift
//  P8-Product
//

import SwiftUI
import SwiftData
import simd

/**
 A SwiftUI view for testing and demonstrating the mole segmentation functionality using the SAM 3.1 model. 
 Displays a test image, allows the user to run segmentation, and shows the results with interactive bounding boxes. 
 Provides controls for adjusting detection parameters and handles the flow of selecting a person and adding new moles or scans based on the segmentation results.
 */
struct MoleSegmentationView: View {
    @Query(sort: \Person.createdAt)
    private var people: [Person]
    @State private var appState: MoleSegmentationAppState

    // MARK: - Init

    /// Creates a segmentation view for the given image and optional depth data.
    ///
    /// - Parameters:
    ///   - inputImage: The image to segment. Pass `nil` to show a placeholder.
    ///   - depthMap: LiDAR depth map captured alongside the image. `nil` for non-AR captures.
    ///   - confidenceMap: Confidence values for each depth pixel. `nil` for non-AR captures.
    ///   - cameraIntrinsics: Camera intrinsics from ARFrame. `nil` for non-AR captures.
    init(
        inputImage: UIImage?,
        depthMap: CVPixelBuffer? = nil,
        confidenceMap: CVPixelBuffer? = nil,
        cameraIntrinsics: simd_float3x3? = nil
    ) {
        let state = MoleSegmentationAppState(dataController: .shared)
        state.depthMap = depthMap
        state.confidenceMap = confidenceMap
        state.cameraIntrinsics = cameraIntrinsics
        if let inputImage {
            state.testImage = inputImage
            state.capturedImageOrientation = inputImage.imageOrientation
        }
        _appState = State(initialValue: state)
    }

    // MARK: - UI-Only State (Gestures)
    @State private var currentZoom: Double = 0.0
    @State private var totalZoom: Double = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        NavigationStack {
            ZStack {
                if let image: UIImage = appState.testImage {
                    imageContent(image: image)
                } else {
                    noImagePlaceholder
                }

                if appState.isProcessing {
                    loadingOverlay
                }
            }
            .navigationTitle("Mole Segmentation")
            .toolbar { toolbarContent }
            .sheet(isPresented: $appState.showSettings) {
                // Assuming settingsSheet is extracted
                settingsSheet
            }
            .confirmationDialog("Who is this scan for?", isPresented: $appState.showPersonPicker) {
                ForEach(people) { person in
                    Button(person.name) {
                        appState.selectedPersonForScan = person
                        appState.resegment()
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog("Mole Action", isPresented: $appState.showMoleActionDialog) {
                Button("New Mole") { appState.handleNewMoleSelection() }
                if let person: Person = appState.selectedPersonForScan, !person.moles.isEmpty {
                    Button("Existing Mole") { appState.showExistingMolePicker = true }
                }
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog("Select Existing Mole", isPresented: $appState.showExistingMolePicker) {
                if let person: Person = appState.selectedPersonForScan {
                    ForEach(person.moles) { mole in
                        Button(mole.name) { appState.handleExistingMoleSelection(mole: mole) }
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .alert(item: $appState.activeAlert) { alert in
                Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("OK")))
            }
        }
    }

    // MARK: - Subviews

    /**
     A view builder that renders the main image content, including the original image, the segmentation mask overlay, and interactive bounding boxes. 
     Uses a `GeometryReader` to handle scaling and positioning of the image and overlays. 
     Applies zoom and pan gestures to allow the user to explore the image in detail. 
     The bounding boxes are rendered as transparent rectangles that can be long-pressed to trigger actions for adding new moles or scans.
     - Parameter image: The original UIImage to be displayed and annotated with segmentation results.
     - Returns: A view containing the image with overlays and interactive elements.
     */
    @ViewBuilder
    private func imageContent(image: UIImage) -> some View {
        GeometryReader { geometry in
            ZStack {
                if let mask: UIImage = appState.maskOverlay {
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

                                ForEach(0..<appState.detectedBoxes.count, id: \.self) { index in
                                    let box: CGRect = appState.detectedBoxes[index]
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
                                            appState.selectedBoxForMole = box
                                            if appState.selectedPersonForScan == nil && people.count == 1 {
                                                appState.selectedPersonForScan = people[0]
                                            }
                                            
                                            if appState.selectedPersonForScan != nil {
                                                appState.showMoleActionDialog = true
                                            } else {
                                                appState.activeAlert = .error("Please segment again to select a person.")
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
                Text(appState.statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 2)
            }
        }
    }

    // MARK: - Supporting views

    /**
     A view builder that renders the settings sheet for adjusting detection parameters. 
     Provides sliders for confidence threshold and NMS overlap threshold, along with explanatory text. 
     The settings are bound to the view's `AppState` instance (`MoleSegmentationAppState`) so changes update the segmentation parameters in real time. 
     Should be presented as a sheet when the user taps the "Settings" button in the toolbar.
     - Returns: A view containing controls for adjusting segmentation parameters.
     */
    private var settingsSheet: some View {
        NavigationStack {
            List {
                Section("Detection Thresholds") {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Confidence:")
                            Spacer()
                            Text(String(format: "%.2f", appState.confidenceThreshold))
                                .monospacedDigit()
                        }
                        Slider(value: $appState.confidenceThreshold, in: 0.00...1.00, step: 0.05)
                    }
                    
                    VStack(alignment: .leading) {
                        HStack {
                            Text("NMS Overlap:")
                            Spacer()
                            Text(String(format: "%.2f", appState.nmsThreshold))
                                .monospacedDigit()
                        }
                        Slider(value: $appState.nmsThreshold, in: 0.00...1.00, step: 0.05)
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
                        appState.showSettings = false
                    }
                }
            }
            .presentationDetents([.height(300)])
        }
    }

    /**
     A view builder that renders a full-screen overlay shown while loading or segmenting. 
     Displays a progress indicator and a status message to inform the user about the current operation. 
     - Returns: A view containing the loading overlay.
     */
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView().scaleEffect(1.5)
                Text(appState.statusMessage)
                    .foregroundStyle(.white)
                    .font(.headline)
            }
            .padding()
            .background(.black.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    /**
     A view builder that renders a placeholder image when no test image is available. 
     Displays a photo icon and a message indicating that no test image was found. 
     - Returns: A view containing the placeholder content.
     */
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

    /**
     A view builder that renders the toolbar content for the navigation bar. 
     Provides buttons for opening settings, starting segmentation, and clearing results. 
     The buttons are disabled based on the processing state to prevent conflicting actions. 
     Should be included in the navigation bar of the main view.
     - Returns: A view containing the toolbar items.
     */
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack {
                Button {
                    appState.showSettings = true
                } label: {
                    Label("Settings", systemImage: "slider.horizontal.3")
                }
                .disabled(appState.isProcessing)

                Button("Segment") { appState.startSegmentationFlow(people: people) }
                    .disabled(appState.isProcessing)
                Button("Clear") { appState.clearSegmentation() }
                    .disabled(appState.maskOverlay == nil)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    MoleSegmentationView(inputImage: UIImage(named: "test_mole_image"))
}
