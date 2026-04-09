import SwiftUI
import SwiftData

@MainActor
@Observable
class MoleSegmentationAppState {
    // MARK: - Machine Learning State
    var testImage: UIImage? = UIImage(named: "test_mole_image")
    var maskOverlay: UIImage?
    var detectedBoxes: [CGRect] = []
    
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
    
    init(dataController: DataController) {
        self.dataController = dataController
    }
    
    // MARK: - ML Logic
    
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
    
    func clearSegmentation() {
        maskOverlay = nil
        detectedBoxes = []
        selectedPersonForScan = nil
        statusMessage = "Cleared"
        modelLoader.segmentor?.clearCache()
    }
    
    // MARK: - Data Saving Logic
    
    func handleNewMoleSelection() {
        guard let person: Person = selectedPersonForScan, let image: UIImage = testImage, let box: CGRect = selectedBoxForMole else { return }
        if let cropped: UIImage = cropImage(image, to: box) {
            dataController.addMoleAndScan(to: person, image: cropped)
            statusMessage = "Added mole to \(person.name)!"
            activeAlert = .success("Successfully saved scan.")
        }
    }
    
    func handleExistingMoleSelection(mole: Mole) {
        guard let image: UIImage = testImage, let box: CGRect = selectedBoxForMole else { return }
        
        // 1. Crop the image here in the AppState
        if let cropped: UIImage = cropImage(image, to: box) {
            
            // 2. Pass the finished image to the DataController
            dataController.addToExistingMole(mole: mole, image: cropped)
            
            // 3. Update UI state
            statusMessage = "Added scan to \(mole.name)!"
            activeAlert = .success("Successfully saved scan.")
        }
    }
    
    // Helper to extract the cropping logic away from the View
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

