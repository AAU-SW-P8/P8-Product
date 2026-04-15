import SwiftUI
import SwiftData
import simd

@MainActor
@Observable
class MoleSegmentationAppState {
    // MARK: - Machine Learning State
    var testImage: UIImage? = UIImage(named: "test_mole_image")
    var maskOverlay: UIImage?
    var maskOnlyImage: UIImage?
    var detectedBoxes: [CGRect] = []
    var depthMap: CVPixelBuffer?
    var confidenceMap: CVPixelBuffer?
    var cameraIntrinsics: simd_float3x3?
    var capturedImageOrientation: UIImage.Orientation = .up
    
    var isProcessing: Bool = false
    var statusMessage: String = "Ready"
    var confidenceThreshold: Float = 0.3
    var nmsThreshold: Float = 1.0
    
    // MARK: - UI Flow Flags
    var showSettings: Bool = false
    var showPersonPicker: Bool = false
    var showMoleActionDialog: Bool = false
    var showExistingMolePicker: Bool = false
    
    // MARK: - Selection State
    var selectedPersonForScan: Person?
    var selectedBoxForMole: CGRect?
    var activeAlert: AlertState?
    
    // Dependencies
    private let dataController: DataController
    private let modelLoader: SAM3ModelLoader = SAM3ModelLoader.shared
    private let calculator = Calculator()
    
    init(dataController: DataController) {
        self.dataController = dataController
    }
    
    // MARK: - ML Logic
    
    /**
     Starts the segmentation flow. 
     If no people exist, shows an error alert. 
     If exactly one person exists, selects that person and starts segmentation immediately. 
     If multiple people exist, shows a person picker dialog.
     - Parameter people: The current list of people to determine the flow.
     */
    func startSegmentationFlow(people: [Person]) {
        if people.isEmpty {
            activeAlert = .error("Please add a person in the Overview first.")
        } else if people.count == 1 {
            selectedPersonForScan = people[0]
            resegment()
        } else {
            showPersonPicker = true
        }
    }
    
    /**
     Performs the segmentation using the loaded model. Updates the UI state with the results or any errors.
     Uses the current `testImage`, `confidenceThreshold`, and `nmsThreshold` values for the segmentation.
     Updates `maskOverlay`, `detectedBoxes`, and `statusMessage` based on the outcome.
     Sets `isProcessing` to true while the segmentation is running, and false when it completes or fails.
     Handles errors by showing an alert with the error message.
     */
    func resegment() {
        guard let segmentor = modelLoader.segmentor, let image = testImage else { return }

        isProcessing = true
        statusMessage = "Segmenting…"
        
        let conf: Float = confidenceThreshold
        let nms: Float = nmsThreshold
        
        Task.detached {
            do {
                let result = try await segmentor.segment(image: image, confidenceThreshold: conf, nmsThreshold: nms)
                await MainActor.run {
                    self.maskOverlay = result?.0
                    self.detectedBoxes = result?.1 ?? []
                    self.maskOnlyImage = result?.2
                    self.statusMessage = result != nil ? "Segmentation complete. Long press a mole to add it." : "No moles detected"
                    self.isProcessing = false
                }
            } catch {
                await MainActor.run {
                    self.activeAlert = .error("Segmentation failed: \(error.localizedDescription)")
                    self.statusMessage = "Error"
                    self.isProcessing = false
                }
            }
        }
    }
    
    /**
     Clears the current segmentation results and resets related state. 
     Also clears the segmentor's cache to free up memory.
     Updates `maskOverlay`, `detectedBoxes`, `selectedPersonForScan`, and `statusMessage` to reflect the cleared state.
     Should be called when the user wants to start fresh or after saving a scan.
     */
    func clearSegmentation() {
        maskOverlay = nil
        maskOnlyImage = nil
        detectedBoxes = []
        selectedBoxForMole = nil
        selectedPersonForScan = nil
        statusMessage = "Cleared"
        modelLoader.segmentor?.clearCache()
    }
    
    // MARK: - Data Saving Logic
    
    /**
     Handles the logic for when a new mole is selected to be added. 
     Validates that a person, image, and box are selected. 
     Crops the image to the selected box and adds it as a new mole and scan to the selected person via the `DataController`. 
     Updates the `statusMessage` and shows a success alert upon completion.
     Should be called when confirming the addition of a new mole after segmentation.
     */
    func handleNewMoleSelection() {
        guard let person: Person = selectedPersonForScan, let image: UIImage = testImage, let box: CGRect = selectedBoxForMole else { return }
        if let cropped: UIImage = cropImage(image, to: box) {
            dataController.addMoleAndScan(to: person, image: cropped, area: calculateSelectedMoleArea())
            statusMessage = "Added mole to \(person.name)!"
            activeAlert = .success("Successfully saved scan.")
        }
    }
    
    /**
     Handles the logic for when an existing mole is selected to add a new scan to. 
     Validates that a mole, image, and box are selected. 
     Crops the image to the selected box and adds it as a new scan to the selected mole via the `DataController`. 
     Updates the `statusMessage` and shows a success alert upon completion.
     Should be called when confirming the addition of a scan to an existing mole after segmentation.
     - Parameter mole: The existing mole to which the new scan should be added.
     */
    func handleExistingMoleSelection(mole: Mole) {
        guard let image: UIImage = testImage, let box: CGRect = selectedBoxForMole else { return }
        
        // 1. Crop the image here in the AppState
        if let cropped: UIImage = cropImage(image, to: box) {
            
            // 2. Pass the finished image to the DataController
            dataController.addToExistingMole(mole: mole, image: cropped, area: calculateSelectedMoleArea())
            
            // 3. Update UI state
            statusMessage = "Added scan to \(mole.name)!"
            activeAlert = .success("Successfully saved scan.")
        }
    }

    /// Computes the physical mole area in mm² for the currently selected detection.
    /// Returns `0` when depth or mask data is not available.
    private func calculateSelectedMoleArea() -> Float {
        guard let maskOnlyImage: UIImage = maskOnlyImage,
              let selectedBox: CGRect = selectedBoxForMole else {
            return 0
        }

        let areaMM2 = calculator.calculateArea(
            from: (maskOnlyImage, [selectedBox]),
            depthMap: depthMap,
            confidenceMap: confidenceMap,
            cameraIntrinsics: cameraIntrinsics,
            imageOrientation: capturedImageOrientation
        )

        guard areaMM2.isFinite, areaMM2 > 0 else { return 0 }
        return Float(areaMM2)
    }
    
    /**
     Crops the given image to the specified box with some padding, ensuring the crop stays within the image bounds. 
     Uses `UIGraphicsImageRenderer` for efficient cropping while maintaining the original image's scale. 
     Returns the cropped image or nil if cropping fails.
     - Parameters:
        - image: The original UIImage to be cropped.
        - box: The CGRect defining the area to crop, in the coordinate space of the original image.
     - Returns: A new UIImage that is cropped to the specified box, or nil if cropping fails.
     */
    private func cropImage(_ image: UIImage, to box: CGRect) -> UIImage? {
        let padding: CGFloat = 20.0
        var cropRect: CGRect = box.insetBy(dx: -padding, dy: -padding)
        let imageRect = CGRect(origin: .zero, size: image.size)
        cropRect = cropRect.intersection(imageRect)
        
        let format: UIGraphicsImageRendererFormat = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        let renderer: UIGraphicsImageRenderer = UIGraphicsImageRenderer(size: cropRect.size, format: format)
        return renderer.image { _ in
            image.draw(at: CGPoint(x: -cropRect.origin.x, y: -cropRect.origin.y))
        }
    }

    // MARK: - Alert State Helper
    
    /**
     An enum representing the state of an alert to be shown in the UI. 
     Can represent either an error or a success message, each with an associated string message. 
     Conforms to `Identifiable` to be used with SwiftUI's alert system, using a unique ID based on the type and content of the message.
     Provides computed properties for the alert title and message to simplify alert presentation in the UI.
     Should be used to represent any user-facing messages that need to be shown as alerts, such as errors during segmentation or confirmations of successful saves.
     */
    enum AlertState: Identifiable {
        case error(String)
        case success(String)

        var id: String {
            switch self {
            case .error(let message):   return "error:\(message)"
            case .success(let message): return "success:\(message)"
            }
        }

        var title: String {
            switch self {
            case .error:   return "Error"
            case .success: return "Success"
            }
        }

        var message: String {
            switch self {
            case .error(let message), .success(let message): return message
            }
        }
    }

}

