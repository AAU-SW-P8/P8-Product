//
// ARCameraViewController.swift
// P8-Product
//

import UIKit
import ARKit
import RealityKit

class ARCameraViewController: UIViewController, ARSessionDelegate {

    // MARK: - Constants

    private static let overlayRed = UIColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1.0)
    private let targetDistance: Float = 0.35   // 35 cm
    private let distanceTolerance: Float = 0.05 // ±5 cm

    // MARK: - Callbacks

    var onCapture: ((UIImage, CVPixelBuffer?, CVPixelBuffer?) -> Void)?
    var onCancel: (() -> Void)?

    // MARK: - Subviews

    private var arView: ARView!
    private var captureButton: UIButton!
    private var measurementDisplay: UIView!
    private var displayLabel: UILabel!
    private var cancelButton: UIButton!

    // MARK: - State

    private var currentDistance: Float = 100.0

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        guard ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) else {
            showAlert(message: "LiDAR is not available on this device")
            return
        }

        setupARView()
        setupUI()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        arView?.session.pause()
    }

    // MARK: - AR Setup

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

    private func setupUI() {
        setupMeasurementDisplay()
        setupCrosshair()
        setupCenterCircle()
        setupCaptureButton()
        setupCancelButton()
        activateConstraints()
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

    private var centerCrosshair: UIView!

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

    private var centerCircle: UIView!

    private func setupCenterCircle() {
        centerCircle = UIView()
        centerCircle.translatesAutoresizingMaskIntoConstraints = false
        centerCircle.layer.borderColor = Self.overlayRed.cgColor
        centerCircle.layer.borderWidth = 3
        centerCircle.backgroundColor = .clear
        centerCircle.layer.cornerRadius = 8
        view.addSubview(centerCircle)
    }


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

    private func setupCancelButton() {
        cancelButton = UIButton(type: .system)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 16)
        cancelButton.setTitleColor(.white, for: .normal)
        cancelButton.addTarget(self, action: #selector(cancel), for: .touchUpInside)
        view.addSubview(cancelButton)
    }

    private func activateConstraints() {
        NSLayoutConstraint.activate([
            centerCrosshair.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            centerCrosshair.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            centerCrosshair.widthAnchor.constraint(equalToConstant: 80),
            centerCrosshair.heightAnchor.constraint(equalToConstant: 80),

            centerCircle.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            centerCircle.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            centerCircle.widthAnchor.constraint(equalToConstant: 16),
            centerCircle.heightAnchor.constraint(equalToConstant: 16),

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

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard arView != nil else { return }

        if let distance = closestDepthDistance(from: frame) ?? raycastDistance(from: frame) {
            currentDistance = distance
            DispatchQueue.main.async { [weak self] in
                self?.updateMeasurementDisplay()
            }
        }
    }

    // MARK: - Depth Measurement

    private func closestDepthDistance(from frame: ARFrame) -> Float? {
        guard let sceneDepth = frame.sceneDepth else { return nil }

        let depthMap = sceneDepth.depthMap
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(depthMap) else { return nil }

        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)

        var minDistance: Float = .greatestFiniteMagnitude

        for y in 0..<height {
            let rowPtr = baseAddress.advanced(by: y * bytesPerRow).assumingMemoryBound(to: Float32.self)
            for x in 0..<width {
                let depth = rowPtr[x]
                if depth > 0.05 && depth < minDistance {
                    minDistance = depth
                }
            }
        }

        return minDistance < .greatestFiniteMagnitude ? minDistance : nil
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

    private func updateMeasurementDisplay() {
        let distanceInCm = currentDistance * 100
        displayLabel.text = String(format: "%.2f cm", distanceInCm)

        let isInRange = abs(currentDistance - targetDistance) <= distanceTolerance

        captureButton.isEnabled = isInRange
        captureButton.backgroundColor = isInRange ? .systemGreen : .systemGray
        measurementDisplay.backgroundColor = isInRange
            ? UIColor(red: 0.2, green: 0.8, blue: 0.3, alpha: 0.9)
            : Self.overlayRed.withAlphaComponent(0.9)
    }

    // MARK: - Actions

    @objc private func capturePhoto() {
        guard let frame = arView?.session.currentFrame else { return }

        // Convert the camera pixel buffer to a UIImage with correct orientation
        let ciImage = CIImage(cvPixelBuffer: frame.capturedImage)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }

        let orientationMap: [UIInterfaceOrientation: UIImage.Orientation] = [
            .portrait: .right,
            .portraitUpsideDown: .left,
            .landscapeLeft: .up,
            .landscapeRight: .down,
        ]
        let windowScene = view.window?.windowScene
        let interfaceOrientation = windowScene?.effectiveGeometry.interfaceOrientation ?? .portrait
        let imageOrientation = orientationMap[interfaceOrientation] ?? .right
        let image = UIImage(cgImage: cgImage, scale: 1.0, orientation: imageOrientation)

        let depthMap = frame.sceneDepth?.depthMap
        let confidenceMap = frame.sceneDepth?.confidenceMap
        
        print(depthMap.debugDescription)
        print(confidenceMap.debugDescription)
        onCapture?(image, depthMap, confidenceMap)
    }

    @objc private func cancel() {
        onCancel?()
    }

    private func showAlert(message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.onCancel?()
        })
        present(alert, animated: true)
    }

    // MARK: - Shape Helpers

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
