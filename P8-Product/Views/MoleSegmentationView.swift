//
//  MoleSegmentationView.swift
//  P8-Product
//
//  Created by Simon Thordal on 3/24/26.
//

import SwiftUI
import SwiftData

/// A view that segments moles using SAM3 with the text prompt "moles".
///
/// Uses the pre-loaded SAM3 pipeline from SAM3ModelLoader
/// and runs segmentation on an image upon user request. Detected mole regions
/// are shown as a semi-transparent overlays on top of the original image.
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
    @State private var statusMessage: String = NSLocalizedString("seg.status.ready", tableName: "Localizable", bundle: .main, value: "Ready", comment: "Initial status message for segmentation view")

    /// Unified alert state — one source of truth so the view only needs a single `.alert` modifier.
    /// SwiftUI doesn't reliably support multiple `.alert` modifiers on the same view chain, so we
    /// represent "error" and "success" as cases of an `Identifiable` enum and drive one alert from it.
    @State private var activeAlert: AlertState?

    /// Dynamic thresholds for segmentation.
    @State private var confidenceThreshold: Float = 0.3
    @State private var nmsThreshold: Float = 1.0

    /// Controls visibility of the settings controls.
    @State private var showSettings = false
    
    @State private var showPersonPicker = false
    @State private var selectedPersonForScan: Person?
    @State private var selectedBoxForMole: CGRect?

    @State private var showMoleActionDialog = false
    @State private var showExistingMolePicker = false

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
            .navigationTitle(NSLocalizedString("seg.nav.title", tableName: "Localizable", bundle: .main, value: "Mole Segmentation", comment: "Navigation title for mole segmentation"))
            .toolbar { toolbarContent }
            .sheet(isPresented: $showSettings) {
                settingsSheet
            }
            .confirmationDialog(NSLocalizedString("seg.personPicker.title", tableName: "Localizable", bundle: .main, value: "Who is this scan for?", comment: "Title for person picker dialog"), isPresented: $showPersonPicker, titleVisibility: .visible) {
                ForEach(people) { person in
                    Button(person.name) {
                        selectedPersonForScan = person
                        resegment()
                    }
                }
                Button(NSLocalizedString("common.cancel", tableName: "Localizable", bundle: .main, value: "Cancel", comment: "Cancel button"), role: .cancel) {}
            }
            .confirmationDialog(NSLocalizedString("seg.moleAction.title", tableName: "Localizable", bundle: .main, value: "Mole Action", comment: "Title for mole action dialog"), isPresented: $showMoleActionDialog, titleVisibility: .visible) {
                Button(NSLocalizedString("seg.moleAction.new", tableName: "Localizable", bundle: .main, value: "New Mole", comment: "Create a new mole")) {
                    if let person = selectedPersonForScan {
                        addMole(to: person, from: testImage, in: selectedBoxForMole)
                    }
                }
                if let person = selectedPersonForScan, !person.moles.isEmpty {
                    Button(NSLocalizedString("seg.moleAction.existing", tableName: "Localizable", bundle: .main, value: "Existing Mole", comment: "Add to existing mole")) {
                        showExistingMolePicker = true
                    }
                }
                Button(NSLocalizedString("common.cancel", tableName: "Localizable", bundle: .main, value: "Cancel", comment: "Cancel button"), role: .cancel) {}
            }
            .confirmationDialog(NSLocalizedString("seg.existingMolePicker.title", tableName: "Localizable", bundle: .main, value: "Select Existing Mole", comment: "Title for existing mole picker"), isPresented: $showExistingMolePicker, titleVisibility: .visible) {
                if let person = selectedPersonForScan {
                    ForEach(person.moles) { mole in
                        Button(mole.name) {
                            addToExistingMole(mole, from: testImage, in: selectedBoxForMole)
                        }
                    }
                }
                Button(NSLocalizedString("common.cancel", tableName: "Localizable", bundle: .main, value: "Cancel", comment: "Cancel button"), role: .cancel) {}
            }
            .alert(item: $activeAlert) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text(NSLocalizedString("common.ok", tableName: "Localizable", bundle: .main, value: "OK", comment: "OK button")))
                )
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
                                            if selectedPersonForScan == nil && people.count == 1 {
                                                selectedPersonForScan = people[0]
                                            }
                                            
                                            if selectedPersonForScan != nil {
                                                showMoleActionDialog = true
                                            } else {
                                                activeAlert = .error(NSLocalizedString("seg.error.selectPersonAgain", tableName: "Localizable", bundle: .main, value: "Please segment again to select a person.", comment: "Prompt to re-segment when no person is selected"))
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
    
    private func startSegmentationFlow() {
        if people.isEmpty {
            activeAlert = .error(NSLocalizedString("seg.error.addPersonFirst", tableName: "Localizable", bundle: .main, value: "Please add a person in the Overview first.", comment: "Prompt to add a person before segmenting"))
        } else if people.count == 1 {
            selectedPersonForScan = people[0]
            resegment()
        } else {
            showPersonPicker = true
        }
    }

    /// Runs segmentation.
    @MainActor
    private func resegment() {
        guard let segmentor = modelLoader.segmentor, let image = testImage else { return }

        // These UI-related state changes are performed on the main actor.
        isProcessing = true
        statusMessage = NSLocalizedString("seg.status.segmenting", tableName: "Localizable", bundle: .main, value: "Segmenting…", comment: "Status while segmentation is running")
        let confidenceThreshold = self.confidenceThreshold
        let nmsThreshold = self.nmsThreshold
        // Don't clear cache if we're just re-segmenting the same image with different thresholds.
        // segmentor.clearCache() 

        // Run the model work off the main actor, then hop back to MainActor for UI updates.
        Task.detached {
            do {
                let result = try await segmentor.segment(image: image, confidenceThreshold: confidenceThreshold, nmsThreshold: nmsThreshold)
                await MainActor.run {
                    self.maskOverlay = result?.0
                    self.detectedBoxes = result?.1 ?? []
                    self.statusMessage = result != nil ? NSLocalizedString("seg.status.completeLongPress", tableName: "Localizable", bundle: .main, value: "Segmentation complete. Long press a mole to add it.", comment: "Shown when segmentation completes with results") : NSLocalizedString("seg.status.noMoles", tableName: "Localizable", bundle: .main, value: "No moles detected", comment: "Shown when no moles are detected")
                    self.isProcessing = false
                }
            } catch {
                await MainActor.run {
                    self.activeAlert = .error(String(format: NSLocalizedString("seg.error.failedFormat", tableName: "Localizable", bundle: .main, value: "Segmentation failed: %@", comment: "Segmentation failed message with error description"), error.localizedDescription))
                    self.statusMessage = NSLocalizedString("seg.status.error", tableName: "Localizable", bundle: .main, value: "Error", comment: "Generic error status")
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
        selectedPersonForScan = nil
        statusMessage = NSLocalizedString("seg.status.cleared", tableName: "Localizable", bundle: .main, value: "Cleared", comment: "Shown after clearing segmentation")
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
            name: String(format: NSLocalizedString("mole.defaultName.format", tableName: "Localizable", bundle: .main, value: "Mole %d", comment: "Default mole name with index"), person.moles.count + 1),
            bodyPart: NSLocalizedString("mole.bodyPart.unassigned", tableName: "Localizable", bundle: .main, value: "Unassigned", comment: "Unassigned body part label"),
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
        
        statusMessage = String(format: NSLocalizedString("seg.status.addedMoleTo.format", tableName: "Localizable", bundle: .main, value: "Added mole to %@!", comment: "Status after adding mole to a person"), person.name)
        activeAlert = .success(NSLocalizedString("seg.success.savedScan", tableName: "Localizable", bundle: .main, value: "Successfully saved scan.", comment: "Alert message when scan saved successfully"))
    }

    private func addToExistingMole(_ mole: Mole, from image: UIImage?, in box: CGRect?) {
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
        
        // Save scan and associate to existing mole
        let scan = MoleScan(imageData: croppedImage.jpegData(compressionQuality: 0.9))
        modelContext.insert(scan)
        
        let instance = MoleInstance(
            diameter: 0,
            area: 0,
            mole: mole,
            moleScan: scan
        )
        modelContext.insert(instance)
        
        statusMessage = String(format: NSLocalizedString("seg.status.addedScanTo.format", tableName: "Localizable", bundle: .main, value: "Added scan to %@!", comment: "Status after adding scan to an existing mole"), mole.name)
        activeAlert = .success(NSLocalizedString("seg.success.savedScan", tableName: "Localizable", bundle: .main, value: "Successfully saved scan.", comment: "Alert message when scan saved successfully"))
    }

    // MARK: - Alert state

    /// Drives the single `.alert` modifier on the view. Using `Identifiable` lets us
    /// present and dismiss the alert via one binding, which avoids SwiftUI's
    /// unreliable behavior when multiple `.alert` modifiers are stacked on the same view.
    private enum AlertState: Identifiable {
        case error(String)
        case success(String)

        /// A stable identifier so SwiftUI can tell cases apart when the state changes.
        var id: String {
            switch self {
            case .error(let message):   return "error:\(message)"
            case .success(let message): return "success:\(message)"
            }
        }

        var title: String {
            switch self {
            case .error:   return NSLocalizedString("common.error.title", tableName: "Localizable", bundle: .main, value: "Error", comment: "Generic error title")
            case .success: return NSLocalizedString("common.success.title", tableName: "Localizable", bundle: .main, value: "Success", comment: "Generic success title")
            }
        }

        var message: String {
            switch self {
            case .error(let message), .success(let message): return message
            }
        }
    }

    // MARK: - Supporting views

    /// A sheet containing controls for confidence and NMS thresholds.
    private var settingsSheet: some View {
        NavigationStack {
            List {
                Section(NSLocalizedString("seg.settings.section.detection", tableName: "Localizable", bundle: .main, value: "Detection Thresholds", comment: "Section title for detection thresholds")) {
                    VStack(alignment: .leading) {
                        HStack {
                            Text(NSLocalizedString("seg.settings.confidence", tableName: "Localizable", bundle: .main, value: "Confidence:", comment: "Confidence threshold label"))
                            Spacer()
                            Text(String(format: "%.2f", confidenceThreshold))
                                .monospacedDigit()
                        }
                        Slider(value: $confidenceThreshold, in: 0.00...1.00, step: 0.05)
                    }
                    
                    VStack(alignment: .leading) {
                        HStack {
                            Text(NSLocalizedString("seg.settings.nmsOverlap", tableName: "Localizable", bundle: .main, value: "NMS Overlap:", comment: "NMS overlap label"))
                            Spacer()
                            Text(String(format: "%.2f", nmsThreshold))
                                .monospacedDigit()
                        }
                        Slider(value: $nmsThreshold, in: 0.00...1.00, step: 0.05)
                        Text(NSLocalizedString("seg.settings.nmsHint", tableName: "Localizable", bundle: .main, value: "Higher values allow more overlapping boxes.", comment: "Hint for NMS overlap"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(NSLocalizedString("seg.settings.nav.title", tableName: "Localizable", bundle: .main, value: "Parameters", comment: "Settings navigation title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("common.done", tableName: "Localizable", bundle: .main, value: "Done", comment: "Done button")) {
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
            Text(NSLocalizedString("seg.placeholder.noImageTitle", tableName: "Localizable", bundle: .main, value: "No test image found", comment: "Title when no test image is present"))
                .font(.headline)
            Text(NSLocalizedString("seg.placeholder.noImageMessage", tableName: "Localizable", bundle: .main, value: "Add an image named 'test_mole_image' to Assets.xcassets", comment: "Message instructing how to add test image"))
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
                    Label(NSLocalizedString("seg.toolbar.settings", tableName: "Localizable", bundle: .main, value: "Settings", comment: "Settings button label"), systemImage: "slider.horizontal.3")
                }
                .disabled(modelLoader.segmentor == nil || isProcessing)

                Button(NSLocalizedString("seg.toolbar.segment", tableName: "Localizable", bundle: .main, value: "Segment", comment: "Segment button")) { startSegmentationFlow() }
                    .disabled(modelLoader.segmentor == nil || isProcessing)
                Button(NSLocalizedString("seg.toolbar.clear", tableName: "Localizable", bundle: .main, value: "Clear", comment: "Clear button")) { clearSegmentation() }
                    .disabled(maskOverlay == nil)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    MoleSegmentationTestView()
}
