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
    @State private var bottomSheetDragOffset: CGFloat = 0
    @State private var selectMolePanelStep: SelectMolePanelStep = .chooseAction
    @State private var shouldResegmentAfterPersonDismiss: Bool = false
    @State private var toastMessage: String?
    @State private var toastDismissTask: Task<Void, Never>?

    private var guidanceStep: MoleSegmentationGuidanceStep {
        MoleSegmentationGuidanceStep.make(
            isProcessing: appState.isProcessing,
            hasDetections: !appState.detectedBoxes.isEmpty,
            hasAttemptedSegmentation: appState.hasAttemptedSegmentation
        )
    }

    private var hasSegmentationResult: Bool {
        appState.maskOverlay != nil || !appState.detectedBoxes.isEmpty
    }

    private var allowsUITestMockSelection: Bool {
        ProcessInfo.processInfo.arguments.contains("-UITest_MockSegmentationResult")
    }

    // MARK: - View Body
    var body: some View {
        ZStack {
            if let image: UIImage = appState.testImage {
                MoleSegmentationImageCanvasView(
                    sourceImage: image,
                    maskOverlay: appState.maskOverlay,
                    detectedBoxes: appState.detectedBoxes,
                    onLongPressDetectedBox: { box in
                        presentSelectionFlow(for: box)
                    }
                )
            } else {
                MoleSegmentationNoImagePlaceholderView()
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
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("moleSegmentationView")
        .toolbar { toolbarContent }
        .safeAreaInset(edge: .top) {
            MoleSegmentationGuidanceCard(step: guidanceStep)
        }
        .safeAreaInset(edge: .bottom) {
            bottomActionArea
        }
        .overlay(alignment: .bottomTrailing) {
            if allowsUITestMockSelection, appState.detectedBoxes.isEmpty == false {
                Button("Use Mock Detection") {
                    guard let firstBox = appState.detectedBoxes.first else { return }
                    presentSelectionFlow(for: firstBox)
                }
                .buttonStyle(.borderedProminent)
                .padding(.trailing, 16)
                .padding(.bottom, 92)
                .accessibilityIdentifier("segmentationUseMockDetectionButton")
            }
        }
        .overlay {
            if appState.showSelectMolePanel {
                bottomSheetBackdropAndPanel
                    .zIndex(10)
            }
        }
        .sheet(isPresented: $appState.showSettings) {
            SegmentationSettingsSheetView(
                showSettings: $appState.showSettings,
                confidenceThreshold: $appState.confidenceThreshold,
                nmsThreshold: $appState.nmsThreshold
            )
        }
        .sheet(isPresented: $appState.showNewMoleMetadataSheet) {
            NewMoleMetadataSheetView(
                showSheet: $appState.showNewMoleMetadataSheet,
                selectedBodyPart: $appState.selectedBodyPart,
                newMoleName: $appState.newMoleName,
                validationMessage: appState.newMoleNameValidationMessage,
                canSave: appState.canSaveNewMole,
                onSave: {
                    appState.handleNewMoleSelection()
                }
            )
        }
        .sheet(isPresented: $appState.showPersonPicker, onDismiss: {
            guard shouldResegmentAfterPersonDismiss else { return }
            shouldResegmentAfterPersonDismiss = false
            Task { @MainActor in
                appState.resegment()
            }
        }) {
            PersonPickerSheetView(
                people: people,
                onSelectPerson: { person in
                    appState.selectedPersonForScan = person
                    shouldResegmentAfterPersonDismiss = true
                    appState.showPersonPicker = false
                },
                onCancel: {
                    shouldResegmentAfterPersonDismiss = false
                    appState.showPersonPicker = false
                }
            )
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
        .onAppear {
            injectUITestSegmentationResultIfNeeded()
        }
        .onChange(of: appState.pendingSuccessToast) { _, newValue in
            guard let newValue else { return }
            showSuccessToast(newValue)
            appState.pendingSuccessToast = nil
        }
    }

    // MARK: - Supporting views
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
        SelectMolePanelView(
            isChoosingAction: selectMolePanelStep == .chooseAction,
            personName: appState.selectedPersonForScan?.name ?? "Unknown Person",
            bodyParts: appState.existingBodyPartsForSelectedPerson(),
            selectedBodyPart: $appState.selectedExistingBodyPart,
            existingMoles: appState.existingMolesForSelectedBodyPart(),
            moleSubtitle: moleSubtitle(for:),
            onChooseExisting: {
                selectMolePanelStep = .existing
            },
            onChooseNewMole: {
                dismissSelectMolePanel()
                appState.beginNewMoleFlow()
            },
            onSelectExistingMole: { mole in
                appState.handleExistingMoleSelection(mole: mole)
                dismissSelectMolePanel()
            },
            onCancel: {
                dismissSelectMolePanel()
            }
        )
    }

    /// Builds the subtitle text for an existing mole row shown in the selection panel.
    /// - Parameter mole: The mole being displayed.
    /// - Returns: A formatted summary containing body part, latest scan date, and current diameter.
    private func moleSubtitle(for mole: Mole) -> String {
        let dateText: String = formattedLastScanDate(for: mole)
        let diameterText: String = formattedCurrentDiameter(for: mole)
        return "\(mole.bodyPart) · Last scanned \(dateText) · \(diameterText)"
    }

    /// Formats the date of the most recent scan for a mole.
    /// - Parameter mole: The mole whose latest scan date is requested.
    /// - Returns: A localized abbreviated date string, or `"--"` if no scans exist.
    private func formattedLastScanDate(for mole: Mole) -> String {
        let latestDate: Date? = mole.scans.map(\.captureDate).max()
        guard let latestDate else { return "--" }
        return latestDate.formatted(date: .abbreviated, time: .omitted)
    }

    /// Formats the diameter from the most recent scan for a mole.
    /// - Parameter mole: The mole whose latest diameter is requested.
    /// - Returns: Diameter text in millimeters with one decimal place, or `"-- mm"` when unavailable.
    private func formattedCurrentDiameter(for mole: Mole) -> String {
        let latestScan: MoleScan? = mole.scans.max {
            $0.captureDate < $1.captureDate
        }

        guard let diameter: Float = latestScan?.diameter, diameter > 0 else {
            return "-- mm"
        }

        return String(format: "%.1f mm", diameter)
    }

    /// Dismisses and resets the select-mole bottom sheet state with animation.
    private func dismissSelectMolePanel() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
            appState.showSelectMolePanel = false
            bottomSheetDragOffset = 0
            selectMolePanelStep = .chooseAction
        }
    }

    private func presentSelectionFlow(for box: CGRect) {
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

    /// Shows a success toast message and schedules automatic dismissal.
    /// - Parameter message: Message to present in the toast.
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

    private func injectUITestSegmentationResultIfNeeded() {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("-UITest_MockSegmentationResult"),
              appState.detectedBoxes.isEmpty,
              let image = appState.testImage else {
            return
        }

        appState.maskOverlay = image
        appState.maskOnlyImage = image
        appState.detectedBoxes = [CGRect(origin: .zero, size: image.size)]
        appState.hasAttemptedSegmentation = true
        appState.statusMessage = "Segmentation complete. Long press a mole to add it."
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
            .accessibilityIdentifier("segmentationSettingsButton")
        }
    }

    private var bottomActionArea: some View {
        MoleSegmentationBottomActionAreaView(
            isProcessing: appState.isProcessing,
            primaryButtonTitle: primaryButtonTitle,
            onPrimaryAction: {
                if hasSegmentationResult {
                    shouldResegmentAfterPersonDismiss = false
                    appState.clearSegmentation()
                } else {
                    appState.startSegmentationFlow(people: people)
                }
            }
        )
    }

    /// Determines the title of the primary action button based on the current state of the app. 
    /// - Returns: A string representing the button title, which changes to indicate whether the app is processing, has results, or is ready to start segmentation.
    private var primaryButtonTitle: String {
        if appState.isProcessing {
            return "Scanning…"
        }
        if hasSegmentationResult {
            return "Clear Results"
        }
        return "Scan for Moles"
    }
}

// MARK: - Preview

#Preview {
    MoleSegmentationView(inputImage: UIImage(named: "test_mole_image"))
}
