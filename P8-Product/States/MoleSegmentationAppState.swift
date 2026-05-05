import SwiftData
import SwiftUI
import UIKit
import simd

/// App state for mole segmentation.
@MainActor
@Observable
class MoleSegmentationAppState {
  // MARK: - Machine Learning State
  /// Test image.
  var testImage: UIImage? = UIImage(named: "test_mole_image")
  /// Mask overlay.
  var maskOverlay: UIImage?
  /// Mask only image.
  var maskOnlyImage: UIImage?
  /// Detected boxes.
  var detectedBoxes: [CGRect] = []
  /// Depth map.
  var depthMap: CVPixelBuffer?
  /// Confidence map.
  var confidenceMap: CVPixelBuffer?
  /// Camera intrinsics.
  var cameraIntrinsics: simd_float3x3?
  /// Captured image orientation.
  var capturedImageOrientation: UIImage.Orientation = .up

  /// Is processing flag.
  var isProcessing: Bool = false
  /// Status message.
  var statusMessage: String = "Ready"
  /// Has attempted segmentation flag.
  var hasAttemptedSegmentation: Bool = false
  /// Confidence threshold.
  var confidenceThreshold: Float = 0.3
  /// NMS threshold.
  var nmsThreshold: Float = 1.0

  // MARK: - UI Flow Flags

  /// Show settings flag.
  var showSettings: Bool = false
  /// Show person picker flag.
  var showPersonPicker: Bool = false
  /// Show mole action dialog flag.
  var showMoleActionDialog: Bool = false
  /// Show existing body part picker flag.
  var showExistingBodyPartPicker: Bool = false
  /// Show existing mole picker flag.
  var showExistingMolePicker: Bool = false
  /// Show new mole metadata sheet flag.
  var showNewMoleMetadataSheet: Bool = false
  /// Show select mole panel flag.
  var showSelectMolePanel: Bool = false

  /// URL of the most recent exported segmentation archive (zip in tmp). Setting this presents the share sheet.
  var exportArchiveURL: ExportArchive?

  // MARK: - Selection State

  /// The selected person for scan.
  var selectedPersonForScan: Person?
  /// The selected box for mole.
  var selectedBoxForMole: CGRect?
  /// The active alert.
  var activeAlert: AlertState?
  /// Pending success toast.
  var pendingSuccessToast: String?
  /// New mole name.
  var newMoleName: String = ""
  /// Selected body part.
  var selectedBodyPart: BodyPart = .unassigned
  /// Selected existing body part.
  var selectedExistingBodyPart: String?

  /// New mole name validation message.
  var newMoleNameValidationMessage: String? {
    guard let person: Person = selectedPersonForScan else { return nil }
    let trimmedName: String = newMoleName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedName.isEmpty else { return nil }

    guard dataController.hasMole(named: trimmedName, for: person) else { return nil }
    return "A mole named \"\(trimmedName)\" already exists for \(person.name)."
  }

  /// Returns whether a new mole can be saved.
  var canSaveNewMole: Bool {
    newMoleNameValidationMessage == nil
  }

  // MARK: - Dependencies

  /// Data controller.
  private let dataController: DataController
  /// SAM3 model loader.
  private let modelLoader: SAM3ModelLoader = SAM3ModelLoader.shared
  /// Calculator for metrics.
  private let calculator = Calculator()
  /// Linear calculator.
  private let calclinear = CalculatorLinear()

  /// Initializes the app state with the given data controller.
  init(dataController: DataController) {
    self.dataController = dataController
  }

  // MARK: - ML Logic

  /// Starts the segmentation flow.
  /// If no people exist, shows an error alert.
  /// If exactly one person exists, selects that person and starts segmentation immediately.
  /// If multiple people exist, shows a person picker dialog.
  /// - Parameter people: The current list of people to determine the flow.
  func startSegmentationFlow(people: [Person]) {
    if people.isEmpty {
      activeAlert = .error("Please add a person in the Overview first.")
    } else if people.count == 1, let onlyPerson: Person = people.first {
      selectedPersonForScan = onlyPerson
      Task {
        await MainActor.run {
          resegment()
        }
      }
    } else {
      showPersonPicker = true
    }
  }

  /// Performs the segmentation using the loaded model. Updates the UI state with the results or any errors.
  /// Uses the current `testImage`, `confidenceThreshold`, and `nmsThreshold` values for the segmentation.
  /// Updates `maskOverlay`, `detectedBoxes`, and `statusMessage` based on the outcome.
  /// Sets `isProcessing` to true while the segmentation is running, and false when it completes or fails.
  /// Handles errors by showing an alert with the error message.
  func resegment() {
    guard let segmentor = modelLoader.segmentor, let image = testImage else { return }

    isProcessing = true
    statusMessage = "Segmenting…"

    let conf: Float = confidenceThreshold
    let nms: Float = nmsThreshold

    Task.detached {
      try? await Task.sleep(for: .milliseconds(50))
      do {
        let result = try await segmentor.segment(
          image: image, confidenceThreshold: conf, nmsThreshold: nms)
        await MainActor.run {
          self.maskOverlay = result?.0
          self.detectedBoxes = result?.1 ?? []
          self.maskOnlyImage = result?.2
          self.hasAttemptedSegmentation = true
          self.statusMessage =
            result != nil
            ? "Segmentation complete. Long press a mole to add it." : "No moles detected"
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

  /// Clears the current segmentation results and resets related state.
  /// Also clears the segmentor's cache to free up memory.
  /// Updates `maskOverlay`, `detectedBoxes`, `selectedPersonForScan`, and `statusMessage` to reflect the cleared state.
  /// Should be called when the user wants to start fresh or after saving a scan.
  func clearSegmentation() {
    Task {
      await MainActor.run {
        self.isProcessing = false
        self.maskOverlay = nil
        self.maskOnlyImage = nil
        self.detectedBoxes = []
        self.showPersonPicker = false
        self.showMoleActionDialog = false
        self.showExistingBodyPartPicker = false
        self.showExistingMolePicker = false
        self.showNewMoleMetadataSheet = false
        self.showSelectMolePanel = false
        self.selectedBoxForMole = nil
        self.selectedPersonForScan = nil
        self.activeAlert = nil
        self.pendingSuccessToast = nil
        self.newMoleName = ""
        self.selectedBodyPart = .unassigned
        self.selectedExistingBodyPart = nil
        self.statusMessage = "Ready"
        self.hasAttemptedSegmentation = false
      }
    }
  }

  // MARK: - Data Saving Logic

  /// Opens the metadata UI for creating a new mole.
  func beginNewMoleFlow() {
    guard selectedBoxForMole != nil else {
      activeAlert = .error("Please long-press a detected mole first.")
      return
    }

    newMoleName = ""
    selectedBodyPart = .unassigned
    showNewMoleMetadataSheet = true
  }

  /// Starts the existing-mole flow by asking for body part first.
  func beginExistingMoleFlow() {
    guard selectedBoxForMole != nil else {
      activeAlert = .error("Please long-press a detected mole first.")
      return
    }

    let bodyParts: [String] = existingBodyPartsForSelectedPerson()
    guard !bodyParts.isEmpty else {
      activeAlert = .error("No existing moles found for this person.")
      return
    }

    selectedExistingBodyPart = nil
    showExistingBodyPartPicker = true
  }

  /// Returns existing body parts for the selected person.
  func existingBodyPartsForSelectedPerson() -> [String] {
    guard let person: Person = selectedPersonForScan else { return [] }
    let uniqueParts: Set<String> = Set(person.moles.map { $0.bodyPart })
    return uniqueParts.sorted { lhs, rhs in
      lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
    }
  }

  /// Returns existing moles for the selected body part.
  func existingMolesForSelectedBodyPart() -> [Mole] {
    guard let person: Person = selectedPersonForScan else { return [] }

    let filteredMoles: [Mole]
    if let bodyPart: String = selectedExistingBodyPart {
      filteredMoles = person.moles.filter { $0.bodyPart == bodyPart }
    } else {
      filteredMoles = person.moles
    }

    return filteredMoles.sorted { lhs, rhs in
      lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
  }

  /// Sets the selected existing body part.
  func chooseExistingBodyPart(_ bodyPart: String) {
    selectedExistingBodyPart = bodyPart
    showExistingMolePicker = true
  }

  /// Handles the logic for when a new mole is selected to be added.
  /// Validates that a person, image, and box are selected.
  /// Crops the image to the selected box and adds it as a new mole and scan to the selected person via the `DataController`.
  /// Updates the `statusMessage` and shows a success alert upon completion.
  /// Should be called when confirming the addition of a new mole after segmentation.
  func handleNewMoleSelection() {
    guard let person: Person = selectedPersonForScan, let image: UIImage = testImage,
      let box: CGRect = selectedBoxForMole
    else { return }

    guard canSaveNewMole else {
      return
    }

    if let cropped: UIImage = cropImage(image, to: box) {
      let measurement = calculateSelectedMoleMeasurement()
      let didSave: Bool = dataController.addMoleAndScan(
        to: person,
        image: cropped,
        name: newMoleName,
        bodyPart: selectedBodyPart.rawValue,
        area: measurement.area,
        diameter: measurement.diameter
      )

      guard didSave else {
        activeAlert = .error("A mole with that name already exists for \(person.name).")
        return
      }

      statusMessage = "Added mole to \(person.name)!"
      pendingSuccessToast = "✓ New mole saved!"
      showNewMoleMetadataSheet = false
      newMoleName = ""
      selectedBodyPart = .unassigned
    }
  }

  /// Handles the logic for when an existing mole is selected to add a new scan to.
  /// Validates that a mole, image, and box are selected.
  /// Crops the image to the selected box and adds it as a new scan to the selected mole via the `DataController`.
  /// Updates the `statusMessage` and shows a success alert upon completion.
  /// Should be called when confirming the addition of a scan to an existing mole after segmentation.
  /// - Parameter mole: The existing mole to which the new scan should be added.
  func handleExistingMoleSelection(mole: Mole) {
    guard let image: UIImage = testImage, let box: CGRect = selectedBoxForMole else { return }

    // 1. Crop the image here in the AppState
    if let cropped: UIImage = cropImage(image, to: box) {
      let measurement = calculateSelectedMoleMeasurement()

      // 2. Pass the finished image to the DataController
      dataController.addToExistingMole(
        mole: mole,
        image: cropped,
        area: measurement.area,
        diameter: measurement.diameter
      )

      // 3. Update UI state
      statusMessage = "Added scan to \(mole.name)!"
      pendingSuccessToast = "✓ Added to \(mole.name)"
      selectedExistingBodyPart = nil
    }
  }

  /// Computes both physical measurements for the selected detection.
  /// Returns `(0, 0)` when required mask/depth data is unavailable.
  private func calculateSelectedMoleMeasurement() -> (area: Float, diameter: Float) {
    guard let maskOnlyImage: UIImage = maskOnlyImage,
      let selectedBox: CGRect = selectedBoxForMole
    else {
      return (0, 0)
    }

    let measurement = calculator.calculateMetrics(
      from: (maskOnlyImage, [selectedBox]),
      depthMap: depthMap,
      confidenceMap: confidenceMap,
      cameraIntrinsics: cameraIntrinsics,
      imageOrientation: capturedImageOrientation,
      model: .linear
    )

    let area =
      measurement.areaMM2.isFinite && measurement.areaMM2 > 0 ? Float(measurement.areaMM2) : 0
    let diameter =
      measurement.diameterMM.isFinite && measurement.diameterMM > 0
      ? Float(measurement.diameterMM) : 0
    return (area, diameter)
  }

  /// Crops the given image to the specified box with some padding, ensuring the crop stays within the image bounds.
  /// Uses `UIGraphicsImageRenderer` for efficient cropping while maintaining the original image's scale.
  /// Returns the cropped image or nil if cropping fails.
  /// - Parameters:
  ///   - image: The original UIImage to be cropped.
  ///   - box: The CGRect defining the area to crop, in the coordinate space of the original image.
  /// - Returns: A new UIImage that is cropped to the specified box, or nil if cropping fails.
  private func cropImage(_ image: UIImage, to box: CGRect) -> UIImage? {
    let padding: CGFloat = 20.0
    var cropRect: CGRect = box.insetBy(dx: -padding, dy: -padding)
    let imageRect = CGRect(origin: .zero, size: image.size)
    cropRect = cropRect.intersection(imageRect)

    let format: UIGraphicsImageRendererFormat = UIGraphicsImageRendererFormat()
    format.scale = image.scale
    let renderer: UIGraphicsImageRenderer = UIGraphicsImageRenderer(
      size: cropRect.size, format: format)
    return renderer.image { _ in
      image.draw(at: CGPoint(x: -cropRect.origin.x, y: -cropRect.origin.y))
    }
  }

  // MARK: - Export

  /// Identifiable wrapper around the exported archive URL so it can drive a SwiftUI sheet.
  struct ExportArchive: Identifiable {
    /// The `id` property.
    let id: UUID = UUID()
    /// Zip file containing the segmentation artifacts.
    let url: URL
  }

  /// Bundles the current image, masks, per-detection crops, and box metadata into a zipped folder
  /// in the temporary directory and stores the resulting URL in `exportArchiveURL` to drive the share sheet.
  /// Shows an error alert if no image is loaded or the export fails.
  func exportSegmentationArtifacts() {
    guard let image: UIImage = testImage else {
      activeAlert = .error("No image to export.")
      return
    }

    do {
      let folder: URL = try writeExportFolder(image: image)
      let archive: URL = try zipFolder(folder)
      exportArchiveURL = ExportArchive(url: archive)
    } catch {
      activeAlert = .error("Export failed: \(error.localizedDescription)")
    }
  }

  /// Writes all artifacts into a freshly created timestamped folder under the temporary directory.
  /// - Parameter image: Current source image to export.
  /// - Returns: URL of the created folder.
  private func writeExportFolder(image: UIImage) throws -> URL {
    let formatter: DateFormatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyyMMdd-HHmmss"
    let timestamp: String = formatter.string(from: Date())
    let folderName: String = "segmentation-export-\(timestamp)"
    let folder: URL = FileManager.default.temporaryDirectory
      .appendingPathComponent(folderName, isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

    if let data: Data = image.pngData() {
      try data.write(to: folder.appendingPathComponent("original.png"))
    }
    if let overlay: UIImage = maskOverlay, let data: Data = overlay.pngData() {
      try data.write(to: folder.appendingPathComponent("mask_overlay.png"))
    }
    if let mask: UIImage = maskOnlyImage, let data: Data = mask.pngData() {
      try data.write(to: folder.appendingPathComponent("mask_only.png"))
    }

    if !detectedBoxes.isEmpty {
      let crops: URL = folder.appendingPathComponent("crops", isDirectory: true)
      let masks: URL = folder.appendingPathComponent("masks", isDirectory: true)
      try FileManager.default.createDirectory(at: crops, withIntermediateDirectories: true)
      try FileManager.default.createDirectory(at: masks, withIntermediateDirectories: true)
      for (index, box) in detectedBoxes.enumerated() {
        if let cropped: UIImage = cropImage(image, to: box),
          let data: Data = cropped.pngData()
        {
          try data.write(to: crops.appendingPathComponent("mole_\(index).png"))
        }
        if let maskFull: UIImage = maskOnlyImage,
          let maskCropped: UIImage = cropImage(maskFull, to: box),
          let data: Data = maskCropped.pngData()
        {
          try data.write(to: masks.appendingPathComponent("mole_\(index).png"))
        }
      }
    }

    let metadata: ExportMetadata = ExportMetadata(
      imageWidth: image.size.width,
      imageHeight: image.size.height,
      imageScale: image.scale,
      imageOrientation: capturedImageOrientation.rawValue,
      confidenceThreshold: confidenceThreshold,
      nmsThreshold: nmsThreshold,
      boxes: detectedBoxes.enumerated().map { index, box in
        ExportBox(
          index: index,
          x: box.origin.x,
          y: box.origin.y,
          width: box.size.width,
          height: box.size.height
        )
      }
    )
    let encoder: JSONEncoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let json: Data = try encoder.encode(metadata)
    try json.write(to: folder.appendingPathComponent("boxes.json"))

    return folder
  }

  /// Zips a folder using `NSFileCoordinator`'s `.forUploading` option and copies the result alongside
  /// the source folder so the URL remains valid past the coordinator block.
  /// - Parameter folder: Folder to zip.
  /// - Returns: URL of the resulting `.zip` file.
  private func zipFolder(_ folder: URL) throws -> URL {
    var coordinatorError: NSError?
    var producedURL: URL?
    var copyError: Error?

    let coordinator: NSFileCoordinator = NSFileCoordinator()
    coordinator.coordinate(readingItemAt: folder, options: [.forUploading], error: &coordinatorError) {
      zippedURL in
      let destination: URL = folder.deletingLastPathComponent()
        .appendingPathComponent("\(folder.lastPathComponent).zip")
      do {
        if FileManager.default.fileExists(atPath: destination.path) {
          try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: zippedURL, to: destination)
        producedURL = destination
      } catch {
        copyError = error
      }
    }

    if let coordinatorError { throw coordinatorError }
    if let copyError { throw copyError }
    guard let producedURL else {
      throw NSError(
        domain: "MoleSegmentationAppState", code: -1,
        userInfo: [NSLocalizedDescriptionKey: "Failed to produce export archive."])
    }
    return producedURL
  }

  /// Top-level metadata recorded alongside the exported images.
  private struct ExportMetadata: Encodable {
    let imageWidth: CGFloat
    let imageHeight: CGFloat
    let imageScale: CGFloat
    let imageOrientation: Int
    let confidenceThreshold: Float
    let nmsThreshold: Float
    let boxes: [ExportBox]
  }

  /// Per-detection box record in image coordinates.
  private struct ExportBox: Encodable {
    let index: Int
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
  }

  // MARK: - Alert State Helper

  /// An enum representing the state of an alert to be shown in the UI.
  /// Can represent either an error or a success message, each with an associated string message.
  /// Conforms to `Identifiable` to be used with SwiftUI's alert system, using a unique ID based on the type and content of the message.
  /// Provides computed properties for the alert title and message to simplify alert presentation in the UI.
  /// Should be used to represent any user-facing messages that need to be shown as alerts, such as errors during segmentation or confirmations of successful saves.
  enum AlertState: Identifiable {
    /// The `error` case.
    case error(String)
    /// The `success` case.
    case success(String)

    /// The `id` property.
    var id: String {
      switch self {
      case .error(let message): return "error:\(message)"
      case .success(let message): return "success:\(message)"
      }
    }

    /// The `title` property.
    var title: String {
      switch self {
      case .error: return "Error"
      case .success: return "Success"
      }
    }

    /// The `message` property.
    var message: String {
      switch self {
      case .error(let message), .success(let message): return message
      }
    }
  }
}
