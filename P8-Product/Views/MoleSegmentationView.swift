//
//  MoleSegmentationView.swift
//  P8-Product
//

import SwiftUI
import SwiftData
import simd

/**
 A SwiftUI view demonstrating the mole segmentation functionality using the SAM 3.1 model.
 Displays a image, allows the user to run segmentation, and shows the results with interactive bounding boxes.
 Provides controls for adjusting detection parameters and handles the flow of selecting a person and adding new moles or scans based on the segmentation results.
 */
struct MoleSegmentationView: View {
    private enum SelectMolePanelStep {
        case chooseAction
        case existing
    }

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

    // UI-Only State (Gestures)
    @State private var currentZoom: Double = 0.0
    @State private var totalZoom: Double = 1.0
    @State private var currentPan: CGSize = .zero
    @State private var accumulatedPan: CGSize = .zero
    @State private var bottomSheetDragOffset: CGFloat = 0
    @State private var selectMolePanelStep: SelectMolePanelStep = .chooseAction
    @State private var toastMessage: String?
    @State private var toastDismissTask: Task<Void, Never>?

    private var guidanceStep: MoleSegmentationGuidanceStep {
        MoleSegmentationGuidanceStep.make(
            isProcessing: appState.isProcessing,
            hasDetections: !appState.detectedBoxes.isEmpty
        )
    }

    private var hasSegmentationResult: Bool {
        appState.maskOverlay != nil || !appState.detectedBoxes.isEmpty
    }

    // MARK: - View Body
    var body: some View {
        ZStack {
            if let image: UIImage = appState.testImage {
                imageContent(image: image)
            } else {
                noImagePlaceholder
            }
        }
        .overlay(alignment: .top) {
            if let toastMessage {
                successToastView(message: toastMessage)
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .navigationTitle("Mole Segmentation")
        .toolbar { toolbarContent }
        .safeAreaInset(edge: .top) {
            MoleSegmentationGuidanceCard(step: guidanceStep)
        }
        .safeAreaInset(edge: .bottom) {
            bottomActionArea
        }
        .overlay {
            if appState.showSelectMolePanel {
                bottomSheetBackdropAndPanel
                    .zIndex(10)
            }
        }
        .sheet(isPresented: $appState.showSettings) {
            // Assuming settingsSheet is extracted
            settingsSheet
        }
        .sheet(isPresented: $appState.showNewMoleMetadataSheet) {
            newMoleMetadataSheet
        }
        .alert("Who is this scan for?", isPresented: $appState.showPersonPicker) {
            ForEach(people) { person in
                Button(person.name) {
                    appState.selectedPersonForScan = person
                    appState.resegment()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Mole Action", isPresented: $appState.showMoleActionDialog) {
            Button("New Mole") { appState.beginNewMoleFlow() }
            if let person: Person = appState.selectedPersonForScan, !person.moles.isEmpty {
                Button("Existing Mole") { appState.beginExistingMoleFlow() }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert(item: $appState.activeAlert) { alert in
            Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("OK")))
        }
        .onChange(of: appState.pendingSuccessToast) { _, newValue in
            guard let newValue else { return }
            showSuccessToast(newValue)
            appState.pendingSuccessToast = nil
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
            let displayedImage: UIImage = appState.maskOverlay ?? image
            let imageAspect: Double = displayedImage.size.width / displayedImage.size.height
            let viewAspect: Double = geometry.size.width / geometry.size.height
            let viewportWidth: Double = imageAspect > viewAspect ? geometry.size.width : geometry.size.height * imageAspect
            let viewportHeight: Double = imageAspect > viewAspect ? geometry.size.width / imageAspect : geometry.size.height
            let viewportSize: CGSize = CGSize(width: viewportWidth, height: viewportHeight)

            let zoom: Double = clampedZoom(totalZoom + currentZoom)
            let pan: CGSize = clampedPan(currentPan, accumulatedPan, for: viewportSize, zoom: zoom)

            ZStack {
                ZStack {
                    if let mask: UIImage = appState.maskOverlay {
                        // Render the fully composited annotated image returned by MoleSegmentor
                        Image(uiImage: mask)
                            .resizable()
                            .scaledToFill()
                            .frame(width: viewportWidth, height: viewportHeight)
                            .overlay {
                                let scaleX: Double = viewportWidth / mask.size.width
                                let scaleY: Double = viewportHeight / mask.size.height
                                let boxes: [CGRect] = appState.detectedBoxes

                                ForEach(Array(boxes.enumerated()), id: \.offset) { _, box in
                                    let rect: CGRect = CGRect(
                                        x: box.minX * scaleX,
                                        y: box.minY * scaleY,
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

                                            if people.isEmpty {
                                                appState.activeAlert = .error("Please add a person in the Overview first.")
                                                return
                                            }

                                            if people.count == 1 {
                                                appState.selectedPersonForScan = people.first
                                            } else if appState.selectedPersonForScan == nil {
                                                appState.selectedPersonForScan = people.first
                                            }

                                            appState.selectedExistingBodyPart = nil
                                            selectMolePanelStep = .chooseAction
                                            bottomSheetDragOffset = 0
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                                appState.showSelectMolePanel = true
                                            }
                                        }
                                }
                            }
                    } else {
                        // Fallback: show the original image before segmentation completes
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: viewportWidth, height: viewportHeight)
                    }
                }
                .frame(width: viewportWidth, height: viewportHeight, alignment: .center)
                .scaleEffect(zoom, anchor: .center)
                .offset(pan)
                .clipped()
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
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
                                currentPan = .zero
                                accumulatedPan = .zero
                            }
                        } else if totalZoom > 5.0 {
                            withAnimation {
                                totalZoom = 5.0
                            }
                        }

                        accumulatedPan = clampedPan(.zero, accumulatedPan, for: viewportSize, zoom: clampedZoom(totalZoom))
                    }
            )
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        guard zoom > 1.0 else {
                            currentPan = .zero
                            return
                        }
                        currentPan = value.translation
                    }
                    .onEnded { _ in
                        guard zoom > 1.0 else {
                            currentPan = .zero
                            accumulatedPan = .zero
                            return
                        }

                        accumulatedPan = clampedPan(currentPan, accumulatedPan, for: viewportSize, zoom: zoom)
                        currentPan = .zero
                    }
            )
        }
    }

    /// Clamps the zoom level to a reasonable range to prevent excessive zooming in or out.
     /// - Parameter value: The proposed zoom level based on user gestures.
     /// - Returns: A zoom level clamped between 1.0 (original size) and 5.0 (5x zoom).
    private func clampedZoom(_ value: Double) -> Double {
        min(max(value, 1.0), 5.0)
    }


    /// Clamps the pan offset to prevent panning beyond the edges of the image when zoomed in.
     /// - Parameters:
     ///   - current: The current pan translation from the ongoing drag gesture.
     ///   - accumulated: The total pan offset accumulated from previous drags.
     ///   - size: The size of the viewport displaying the image.
     ///   - zoom: The current zoom level to calculate how much extra space is available for panning.
     /// - Returns: A CGSize representing the clamped pan offset to be applied to the image.
    private func clampedPan(_ current: CGSize, _ accumulated: CGSize, for size: CGSize, zoom: Double) -> CGSize {
        guard zoom > 1.0 else { return .zero }

        let maxX: CGFloat = (size.width * (zoom - 1.0)) / 2.0
        let maxY: CGFloat = (size.height * (zoom - 1.0)) / 2.0
        let proposedX: CGFloat = accumulated.width + current.width
        let proposedY: CGFloat = accumulated.height + current.height

        return CGSize(
            width: min(max(proposedX, -maxX), maxX),
            height: min(max(proposedY, -maxY), maxY)
        )
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

    private var bottomSheetBackdropAndPanel: some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(.black.opacity(0.35))
                .overlay {
                    Rectangle().fill(.ultraThinMaterial.opacity(0.45))
                }
                .ignoresSafeArea()
                .onTapGesture {
                    dismissSelectMolePanel()
                }

            selectMolePanel
                .offset(y: max(bottomSheetDragOffset, 0))
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if value.translation.height > 0 {
                                bottomSheetDragOffset = value.translation.height
                            }
                        }
                        .onEnded { value in
                            if value.translation.height > 120 {
                                dismissSelectMolePanel()
                            } else {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                                    bottomSheetDragOffset = 0
                                }
                            }
                        }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: appState.showSelectMolePanel)
    }

    private var selectMolePanel: some View {
        VStack(spacing: 14) {
            if selectMolePanelStep == .chooseAction {
                panelActionChooser
            } else {
                panelExistingSection
                panelCancelButton
            }
        }
        .padding(.top, 14)
        .padding(.bottom, 12)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.systemGray6).opacity(0.96))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                }
        )
        .frame(height: 520, alignment: .top)
        .padding(.horizontal, 12)
        .ignoresSafeArea(edges: .bottom)
    }

    private var panelActionChooser: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CHOOSE AN ACTION")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            panelExistingMoleButton
            panelOrDivider
            panelNewMoleButton
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 4)
    
    }

    private var panelExistingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            panelHeaderCard

            Rectangle()
                .fill(.white.opacity(0.14))
                .frame(height: 1)
                .frame(maxWidth: .infinity)

            Text("ADD TO AN EXISTING MOLE RECORD")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            panelMoleRows
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    private var panelHeaderCard: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(appState.selectedPersonForScan?.name ?? "Unknown Person")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)

            Spacer(minLength: 8)

            HStack(alignment: .center, spacing: 6) {
                Text("Body part")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Picker("Body Part", selection: $appState.selectedExistingBodyPart) {
                    Text("All").tag(Optional<String>.none)
                    ForEach(appState.existingBodyPartsForSelectedPerson(), id: \.self) { bodyPart in
                        Text(bodyPart).tag(Optional(bodyPart))
                    }
                }
                .labelsHidden()
                .tint(.white)
                .font(.subheadline)
            }
            .pickerStyle(.menu)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.black.opacity(0.25))
        )
    }

    @ViewBuilder
    private var panelMoleRows: some View {
        let existingMoles: [Mole] = appState.existingMolesForSelectedBodyPart()
        if existingMoles.isEmpty {
            Text("No existing moles for this selection.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.vertical, 6)
        } else {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(existingMoles) { mole in
                        existingMoleRow(mole: mole)
                    }
                }
            }
            .frame(maxHeight: 220)
        }
    }

    private var panelOrDivider: some View {
        HStack(spacing: 12) {
            Rectangle().fill(.white.opacity(0.12)).frame(height: 1)
            Text("or")
                .font(.caption)
                .foregroundStyle(.secondary)
            Rectangle().fill(.white.opacity(0.12)).frame(height: 1)
        }
        .padding(.horizontal, 16)
    }

    private var panelExistingMoleButton: some View {
        Button {
            selectMolePanelStep = .existing
        } label: {
            HStack {
                Text("Add to an existing mole")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                Spacer()
                Text("→")
                    .font(.headline)
                    .foregroundStyle(.blue)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.black.opacity(0.3))
            )
        }
        .buttonStyle(.plain)
    }

    private var panelNewMoleButton: some View {
        Button {
            dismissSelectMolePanel()
            appState.beginNewMoleFlow()
        } label: {
            HStack {
                Text("Start tracking as a new mole")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))

                Spacer()

                Text("+")
                    .font(.headline)
                    .foregroundStyle(.blue)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .frame(height: 56)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [6]))
                    .foregroundStyle(.white.opacity(0.35))
            )
        }
        .buttonStyle(.plain)
    }

    private var panelCancelButton: some View {
        Button("Cancel") {
            dismissSelectMolePanel()
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .padding(.bottom, 16)
    }

    @ViewBuilder
    private func existingMoleRow(mole: Mole) -> some View {
        Button {
            appState.handleExistingMoleSelection(mole: mole)
            dismissSelectMolePanel()
        } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.black.opacity(0.4))
                    .frame(width: 34, height: 34)
                    .overlay {
                        Circle()
                            .fill(.white.opacity(0.8))
                            .frame(width: 8, height: 8)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(mole.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    Text(moleSubtitle(for: mole))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 12)

                Text("Add →")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.blue)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.black.opacity(0.3))
            )
        }
        .buttonStyle(.plain)
    }

    private func moleSubtitle(for mole: Mole) -> String {
        let dateText: String = formattedLastScanDate(for: mole)
        let diameterText: String = formattedCurrentDiameter(for: mole)
        return "\(mole.bodyPart) · Last scanned \(dateText) · \(diameterText)"
    }

    private func formattedLastScanDate(for mole: Mole) -> String {
        let latestDate: Date? = mole.instances.compactMap { $0.moleScan?.captureDate }.max()
        guard let latestDate else { return "--" }
        return latestDate.formatted(date: .abbreviated, time: .omitted)
    }

    private func formattedCurrentDiameter(for mole: Mole) -> String {
        let latestInstance: MoleInstance? = mole.instances.max {
            ($0.moleScan?.captureDate ?? .distantPast) < ($1.moleScan?.captureDate ?? .distantPast)
        }

        guard let diameter: Float = latestInstance?.diameter, diameter > 0 else {
            return "-- mm"
        }

        return String(format: "%.1f mm", diameter)
    }

    private func dismissSelectMolePanel() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
            appState.showSelectMolePanel = false
            bottomSheetDragOffset = 0
            selectMolePanelStep = .chooseAction
        }
    }

    private func successToastView(message: String) -> some View {
        Text(message)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color(.blue).opacity(0.95))
                    .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
            )
    }

    private func showSuccessToast(_ message: String) {
        toastDismissTask?.cancel()
        withAnimation(.easeOut(duration: 0.22)) {
            toastMessage = message
        }

        toastDismissTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeIn(duration: 0.2)) {
                    toastMessage = nil
                }
            }
        }
    }

    /// A view builder that renders the metadata entry sheet for adding a new mole based on a segmentation result. 
    /// Provides a picker for selecting the body part and a text field for entering the mole name, along with validation feedback. 
    /// The "Save" button is disabled until the required information is provided and valid. 
    /// Should be presented as a sheet when the user chooses to add a new mole after long-pressing a detected box.
    /// - Returns: A view containing fields for entering new mole metadata.
    private var newMoleMetadataSheet: some View {
        NavigationStack {
            Form {
                Section("Body Part") {
                    Picker("Body Part", selection: $appState.selectedBodyPart) {
                        ForEach(BodyPart.allCases) { bodyPart in
                            Text(bodyPart.rawValue).tag(bodyPart)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Mole Name") {
                    TextField("Mole name", text: $appState.newMoleName)
                    if let validationMessage: String = appState.newMoleNameValidationMessage {
                        Text(validationMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    Text("Optional. Leave empty to auto-generate a name.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("New Mole")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        appState.showNewMoleMetadataSheet = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        appState.handleNewMoleSelection()
                    }
                    .disabled(!appState.canSaveNewMole)
                }
            }
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
            Button {
                appState.showSettings = true
            } label: {
                Label("Settings", systemImage: "slider.horizontal.3")
            }
            .disabled(appState.isProcessing)
        }
    }

    /// Creates the bottom action area containing the primary action button and a privacy note.
    /// The primary button's title and action change based on whether the app is currently processing, has segmentation results, or is ready to start segmentation.
    /// - Returns: A view containing the primary action button and a note about photo privacy.
    private var bottomActionArea: some View {
        VStack(spacing: 8) {
            Button {
                if hasSegmentationResult {
                    appState.clearSegmentation()
                } else {
                    appState.startSegmentationFlow(people: people)
                }
            } label: {
                HStack(spacing: 10) {
                    if appState.isProcessing {
                        ProgressView()
                            .tint(.white)
                    }

                    Text(primaryButtonTitle)
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.blue)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(appState.isProcessing)

            Text("Your photos never leave your device")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }

    /// Determines the title of the primary action button based on the current state of the app. 
    /// - Returns: A string representing the button title, which changes to indicate whether the app is processing, has results, or is ready to start segmentation.
    private var primaryButtonTitle: String {
        if appState.isProcessing {
            return "Scanning…"
        }
        if hasSegmentationResult {
            return "Clear & Restart"
        }
        return "Scan for Moles"
    }
}

// MARK: - Preview

#Preview {
    MoleSegmentationView(inputImage: UIImage(named: "test_mole_image"))
}
