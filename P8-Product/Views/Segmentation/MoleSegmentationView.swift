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

    // MARK: - View Body
    var body: some View {
        ZStack {
            if let image: UIImage = appState.testImage {
                MoleSegmentationImageCanvasView(
                    sourceImage: image,
                    maskOverlay: appState.maskOverlay,
                    detectedBoxes: appState.detectedBoxes,
                    onLongPressDetectedBox: { box in
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
