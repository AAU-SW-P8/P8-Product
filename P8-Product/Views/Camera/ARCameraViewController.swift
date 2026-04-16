//
// ARCameraViewController.swift
// P8-Product
//

import UIKit
import ARKit
import RealityKit
import simd

/// UIKit view controller that drives the LiDAR-assisted capture flow.
///
/// Runs an `ARView` with scene-depth enabled, continuously measures the
/// distance to the nearest surface in front of the camera, and only enables
/// the capture button when the user is within ±`distanceTolerance` of
/// `targetDistance`. Distance is derived from the LiDAR depth buffer when
/// available, falling back to a raycast through screen center. On capture,
/// the current camera frame is converted to a `UIImage` (with correct
/// interface-orientation rotation) and delivered, together with the raw
/// depth and confidence buffers, via the `onCapture` callback. `onCancel`
/// is invoked when the user taps cancel or when LiDAR is unsupported.
final class ARCameraViewController: UIViewController, ARSessionDelegate {

    // MARK: - Constants

    /// Overlay color used for the out-of-range state (measurement pill + crosshair).
    private static let overlayRed = UIColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1.0)
    /// Overlay color used for the in-range state (measurement pill).
    private static let overlayGreen = UIColor(red: 0.2, green: 0.8, blue: 0.3, alpha: 0.9)
    /// Desired subject distance in meters. Captures only become enabled
    /// within `distanceTolerance` of this value.
    private let targetDistance: Float = 0.35   // 35 cm
    /// Allowed deviation around `targetDistance`, in meters.
    private let distanceTolerance: Float = 0.05 // ±5 cm

    // MARK: - Callbacks

    var onCapture: ((UIImage, CVPixelBuffer?, CVPixelBuffer?, simd_float3x3?) -> Void)?
    var onCancel: (() -> Void)?

    // MARK: - Subviews

    private var arView: ARView!
    private var captureButton: UIButton!
    private var measurementDisplay: UIView!
    private var displayLabel: UILabel!
    private var cancelButton: UIButton!
    private var lidarPointsLayer: CAShapeLayer!
    private var centerCrosshair: UIView!

    // MARK: - State

    /// Most recent subject distance in meters, seeded to a large value so the
    /// capture button starts disabled.
    private var currentDistance: Float = 100.0

    // MARK: - Lifecycle

    /// Verifies LiDAR support, then builds the AR session and the capture UI.
    /// Presents an error alert and surfaces `onCancel` if the device cannot
    /// do scene-reconstruction meshing.
    override func viewDidLoad() {
        super.viewDidLoad()

        guard ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) else {
            showAlert(message: "LiDAR is not available on this device")
            return
        }

        setupARView()
        setupUI()
        setupLidarPointsLayer()
    }

    /// Pauses the AR session when the controller goes off-screen so the
    /// camera and LiDAR stop producing frames while hidden.
    ///
    /// - Parameter animated: Forwarded from UIKit.
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        arView?.session.pause()
    }

    // MARK: - AR Setup

    /// Creates the `ARView`, registers as session delegate, and starts a
    /// world-tracking configuration with mesh reconstruction and scene-depth
    /// semantics when the hardware supports them.
    private func setupARView() {
        arView = ARView(frame: view.bounds)
        arView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(arView)

        arView.session.delegate = self

        let configuration = ARWorldTrackingConfiguration()
        configuration.sceneReconstruction = .mesh
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics.insert(.sceneDepth)
        }
        configuration.environmentTexturing = .automatic

        arView.session.run(configuration)
    }

    // MARK: - UI Setup

    /// Builds every custom subview in a single pass and activates their
    /// Auto Layout constraints.
    private func setupUI() {
        setupMeasurementDisplay()
        setupCrosshair()
        setupCaptureButton()
        setupCancelButton()
        activateConstraints()
    }

    private func setupLidarPointsLayer() {
        lidarPointsLayer = CAShapeLayer()
        lidarPointsLayer.frame = view.bounds
        
        // Use a mask to only show dots inside the red box (80x80 centered)
        let maskSize: CGFloat = 80
        let maskRect = CGRect(x: view.bounds.midX - maskSize/2,
                              y: view.bounds.midY - maskSize/2,
                              width: maskSize,
                              height: maskSize)
        let maskLayer = CAShapeLayer()
        maskLayer.path = UIBezierPath(rect: maskRect).cgPath
        lidarPointsLayer.mask = maskLayer
        
        view.layer.addSublayer(lidarPointsLayer)
    }

    private func setupMeasurementDisplay() {
        measurementDisplay = UIView()
        measurementDisplay.translatesAutoresizingMaskIntoConstraints = false
        measurementDisplay.backgroundColor = Self.overlayRed.withAlphaComponent(0.9)
        measurementDisplay.layer.cornerRadius = 12
        measurementDisplay.clipsToBounds = true
        view.addSubview(measurementDisplay)

        displayLabel = UILabel()
        displayLabel.translatesAutoresizingMaskIntoConstraints = false
        displayLabel.textAlignment = .center
        displayLabel.font = .systemFont(ofSize: 28, weight: .bold)
        displayLabel.textColor = .white
        displayLabel.text = "35.00 cm"
        measurementDisplay.addSubview(displayLabel)
    }

    /// Creates the four-corner framing crosshair centered on the screen by
    /// drawing each corner as a `CAShapeLayer` inside a container view.
    private func setupCrosshair() {
        centerCrosshair = UIView()
        centerCrosshair.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(centerCrosshair)

        let size: CGFloat = 80
        let cornerLength: CGFloat = 20
        let paths = Self.crosshairCornerPaths(size: size, cornerLength: cornerLength)

        for path in paths {
            let layer = CAShapeLayer()
            layer.path = path.cgPath
            layer.strokeColor = Self.overlayRed.cgColor
            layer.lineWidth = 2
            layer.fillColor = UIColor.clear.cgColor
            centerCrosshair.layer.addSublayer(layer)
        }
    }


    /// Builds the primary capture button. Starts disabled — it's only
    /// enabled by `updateMeasurementDisplay` once the subject is in range.
    private func setupCaptureButton() {
        captureButton = UIButton(type: .system)
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        captureButton.setTitle("Capture", for: .normal)
        captureButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        captureButton.backgroundColor = .systemGray
        captureButton.setTitleColor(.white, for: .normal)
        captureButton.layer.cornerRadius = 25
        captureButton.isEnabled = false
        captureButton.addTarget(self, action: #selector(capturePhoto), for: .touchUpInside)
        view.addSubview(captureButton)
    }

    /// Builds the cancel button anchored to the top-leading safe area.
    private func setupCancelButton() {
        cancelButton = UIButton(type: .system)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 16)
        cancelButton.setTitleColor(.white, for: .normal)
        cancelButton.addTarget(self, action: #selector(cancel), for: .touchUpInside)
        view.addSubview(cancelButton)
    }

    /// Pins the crosshair, measurement pill, capture button, and cancel
    /// button to the view with Auto Layout.
    private func activateConstraints() {
        NSLayoutConstraint.activate([
            centerCrosshair.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            centerCrosshair.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            centerCrosshair.widthAnchor.constraint(equalToConstant: 80),
            centerCrosshair.heightAnchor.constraint(equalToConstant: 80),

            measurementDisplay.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            measurementDisplay.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            measurementDisplay.widthAnchor.constraint(equalToConstant: 200),
            measurementDisplay.heightAnchor.constraint(equalToConstant: 70),

            displayLabel.topAnchor.constraint(equalTo: measurementDisplay.topAnchor, constant: 8),
            displayLabel.centerXAnchor.constraint(equalTo: measurementDisplay.centerXAnchor),

            captureButton.bottomAnchor.constraint(equalTo: measurementDisplay.topAnchor, constant: -30),
            captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            captureButton.widthAnchor.constraint(equalToConstant: 200),
            captureButton.heightAnchor.constraint(equalToConstant: 50),

            cancelButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            cancelButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
        ])
    }

    // MARK: - ARSessionDelegate

    /// Called for every AR frame. Prefers the dense LiDAR depth map for a
    /// minimum-distance estimate; falls back to a single raycast through the
    /// screen center when depth data isn't available. Refreshes the on-screen
    /// measurement asynchronously on the main queue.
    ///
    /// - Parameters:
    ///   - session: The AR session emitting the frame (unused).
    ///   - frame: The latest frame, containing camera imagery and optional
    ///     scene-depth data.
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard arView != nil else { return }

        if let distance = closestDepthDistance(from: frame) ?? raycastDistance(from: frame) {
            currentDistance = distance
            DispatchQueue.main.async { [weak self] in
                self?.updateMeasurementDisplay()
                self?.updateLidarDots(from: frame)
            }
        }
    }

    // MARK: - Depth Measurement

    /// Scans the entire LiDAR depth map for the closest non-trivial sample.
    ///
    /// Values below 5 cm are ignored because they are almost always sensor
    /// noise or the user's finger occluding the lens.
    ///
    /// - Parameter frame: The AR frame whose `sceneDepth` should be inspected.
    /// - Returns: The nearest valid depth in meters, or `nil` when the frame
    ///   has no depth data or every sample was filtered out.
    private func closestDepthDistance(from frame: ARFrame) -> Float? {
        guard let sceneDepth = frame.sceneDepth else { return nil }

        let depthMap = sceneDepth.depthMap
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(depthMap) else { return nil }

        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)

        // The red box is 80x80 in the center of the view.
        // We crop the depth map search area to match this central region.
        let viewSize = view.bounds.size
        let cropWidthRatio = 80.0 / viewSize.width
        let cropHeightRatio = 80.0 / viewSize.height
        
        let xStart = Int(CGFloat(width) * (1.0 - cropWidthRatio) / 2.0)
        let xEnd = Int(CGFloat(width) * (1.0 + cropWidthRatio) / 2.0)
        let yStart = Int(CGFloat(height) * (1.0 - cropHeightRatio) / 2.0)
        let yEnd = Int(CGFloat(height) * (1.0 + cropHeightRatio) / 2.0)

        var minDistance: Float = .greatestFiniteMagnitude

        for y in max(0, yStart)..<min(height, yEnd) {
            let rowPtr = baseAddress.advanced(by: y * bytesPerRow).assumingMemoryBound(to: Float32.self)
            for x in max(0, xStart)..<min(width, xEnd) {
                let depth = rowPtr[x]
                if depth > 0.05 && depth < minDistance {
                    minDistance = depth
                }
            }
        }

        return minDistance < .greatestFiniteMagnitude ? minDistance : nil
    }

    private func updateLidarDots(from frame: ARFrame) {
        guard let sceneDepth = frame.sceneDepth else {
            lidarPointsLayer.path = nil
            return
        }

        let depthMap = sceneDepth.depthMap
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(depthMap) else { return }

        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)

        let viewSize = view.bounds.size
        let dotPath = UIBezierPath()
        let dotSize: CGFloat = 2.0

        // Subsample the depth map to avoid too many dots
        let step = 4
        for y in stride(from: 0, to: height, by: step) {
            let rowPtr = baseAddress.advanced(by: y * bytesPerRow).assumingMemoryBound(to: Float32.self)
            for x in stride(from: 0, to: width, by: step) {
                let depth = rowPtr[x]
                if depth > 0.05 && depth < 2.0 { // Only show points within 2 meters
                    let vx = CGFloat(x) / CGFloat(width) * viewSize.width
                    let vy = CGFloat(y) / CGFloat(height) * viewSize.height
                    dotPath.append(UIBezierPath(ovalIn: CGRect(x: vx - dotSize/2, y: vy - dotSize/2, width: dotSize, height: dotSize)))
                }
            }
        }

        lidarPointsLayer.path = dotPath.cgPath
        lidarPointsLayer.fillColor = UIColor.white.withAlphaComponent(0.6).cgColor
    }

    private func raycastDistance(from frame: ARFrame) -> Float? {
        let screenCenter = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
        guard let ray = arView.ray(through: screenCenter) else { return nil }
        let query = ARRaycastQuery(origin: ray.origin, direction: ray.direction,
                                   allowing: .estimatedPlane, alignment: .any)
        guard let result = arView.session.raycast(query).first else { return nil }

        let hit = SIMD3<Float>(result.worldTransform.columns.3.x,
                               result.worldTransform.columns.3.y,
                               result.worldTransform.columns.3.z)
        let cam = SIMD3<Float>(frame.camera.transform.columns.3.x,
                               frame.camera.transform.columns.3.y,
                               frame.camera.transform.columns.3.z)
        return simd_distance(cam, hit)
    }

    // MARK: - UI Updates

    /// Refreshes the measurement label and recolors the pill/button according
    /// to whether `currentDistance` is within tolerance of `targetDistance`.
    /// Must be called on the main thread.
    private func updateMeasurementDisplay() {
        let distanceInCm = currentDistance * 100
        displayLabel.text = String(format: "%.2f cm", distanceInCm)

        let isInRange = abs(currentDistance - targetDistance) <= distanceTolerance

        captureButton.isEnabled = isInRange
        captureButton.backgroundColor = isInRange ? .systemGreen : .systemGray
        measurementDisplay.backgroundColor = isInRange
            ? Self.overlayGreen
            : Self.overlayRed.withAlphaComponent(0.9)
    }

    // MARK: - Actions

    /// Grabs the current AR frame, converts its camera pixel buffer into a
    /// correctly-oriented `UIImage`, and forwards the image together with the
    /// frame's depth and confidence buffers through `onCapture`.
    @objc private func capturePhoto() {
        guard let frame = arView?.session.currentFrame else { return }

        // Convert the camera pixel buffer to a UIImage with correct orientation
        let ciImage = CIImage(cvPixelBuffer: frame.capturedImage)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }

        let interfaceOrientation = view.window?.windowScene?.effectiveGeometry.interfaceOrientation ?? .portrait
        let image = UIImage(cgImage: cgImage, scale: 1.0, orientation: Self.imageOrientation(for: interfaceOrientation))

        onCapture?(image, frame.sceneDepth?.depthMap, frame.sceneDepth?.confidenceMap, frame.camera.intrinsics)
    }

    /// Forwards the cancel action to the owning SwiftUI layer.
    @objc private func cancel() {
        onCancel?()
    }

    /// Presents a simple error alert whose OK action invokes `onCancel` so
    /// the presenting SwiftUI view can dismiss this controller.
    ///
    /// - Parameter message: The body text to display.
    private func showAlert(message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.onCancel?()
        })
        present(alert, animated: true)
    }

    // MARK: - Shape Helpers

    /// Maps a UIKit interface orientation to the `UIImage.Orientation` that
    /// rotates the AR camera's raw pixel buffer so it renders upright.
    ///
    /// - Parameter interfaceOrientation: The current window scene interface
    ///   orientation.
    /// - Returns: The matching image orientation, defaulting to `.right`
    ///   (portrait) for unknown values.
    private static func imageOrientation(for interfaceOrientation: UIInterfaceOrientation) -> UIImage.Orientation {
        switch interfaceOrientation {
        case .portrait:            return .right
        case .portraitUpsideDown:  return .left
        case .landscapeLeft:       return .up
        case .landscapeRight:      return .down
        default:                   return .right
        }
    }

    /// Builds the four `UIBezierPath`s used to draw each corner of the
    /// framing crosshair.
    ///
    /// - Parameters:
    ///   - size: Side length of the square crosshair container.
    ///   - cornerLength: Length of each corner stroke, measured along one
    ///     edge of the square.
    /// - Returns: Four paths in top-left, top-right, bottom-right, bottom-left
    ///   order, each expressed in the container's local coordinate space.
    private static func crosshairCornerPaths(size: CGFloat, cornerLength: CGFloat) -> [UIBezierPath] {
        let tl = UIBezierPath()
        tl.move(to: CGPoint(x: 0, y: cornerLength))
        tl.addLine(to: .zero)
        tl.addLine(to: CGPoint(x: cornerLength, y: 0))

        let tr = UIBezierPath()
        tr.move(to: CGPoint(x: size - cornerLength, y: 0))
        tr.addLine(to: CGPoint(x: size, y: 0))
        tr.addLine(to: CGPoint(x: size, y: cornerLength))

        let br = UIBezierPath()
        br.move(to: CGPoint(x: size, y: size - cornerLength))
        br.addLine(to: CGPoint(x: size, y: size))
        br.addLine(to: CGPoint(x: size - cornerLength, y: size))

        let bl = UIBezierPath()
        bl.move(to: CGPoint(x: cornerLength, y: size))
        bl.addLine(to: CGPoint(x: 0, y: size))
        bl.addLine(to: CGPoint(x: 0, y: size - cornerLength))

        return [tl, tr, br, bl]
    }
}
