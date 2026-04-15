// 
// CameraView.swift
// P8-Product
//

import SwiftUI
import SwiftData
import UIKit
import ARKit
import simd
import Vision
import CoreVideo

struct CameraView: View {
    @State private var selectedImage: UIImage?
    @State private var showARCamera = false
    @State private var hasAutoOpenedCamera = false
    private let supportsARCapture = ARWorldTrackingConfiguration.isSupported
        && ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)

    var body: some View {
        ZStack {
            if let selectedImage {
                Image(uiImage: selectedImage)
                    .resizable()
                    .scaledToFit()
                    .ignoresSafeArea()
                    .onTapGesture {
                        openARCamera()
                    }
            } else if !supportsARCapture {
                simulatorFallbackView
            } else {
                Color.black
                    .ignoresSafeArea()

                VStack(spacing: 12) {
                    Text(NSLocalizedString("camera.opening", tableName: "Localizable", bundle: .main, value: "Opening camera...", comment: "Shown while opening AR camera"))
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(NSLocalizedString("camera.hint.tapToOpen", tableName: "Localizable", bundle: .main, value: "If camera is closed, tap anywhere to open again", comment: "Hint to reopen camera"))
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                .multilineTextAlignment(.center)
                .padding(24)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !showARCamera {
                openARCamera()
            }
        }
        .onAppear {
            guard !hasAutoOpenedCamera else { return }
            hasAutoOpenedCamera = true
            openARCamera()
        }
        .fullScreenCover(isPresented: $showARCamera) {
            ARCameraView(capturedImage: $selectedImage)
                .ignoresSafeArea()
        }
    }

    private func openARCamera() {
        guard supportsARCapture else { return }
        showARCamera = true
    }

    private var simulatorFallbackView: some View {
        LinearGradient(
            colors: [Color(.systemGray6), Color(.systemGray4)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        .overlay {
            VStack(spacing: 20) {
                Image(systemName: "iphone.slash")
                    .font(.system(size: 56))
                    .foregroundStyle(.secondary)

                Text(NSLocalizedString("camera.sim.unavailable", tableName: "Localizable", bundle: .main, value: "AR capture is unavailable in Simulator", comment: "Title shown when AR is unavailable in Simulator"))
                    .font(.title3.weight(.semibold))

                Text(NSLocalizedString("camera.sim.instructions", tableName: "Localizable", bundle: .main, value: "Run on a LiDAR-equipped iPhone or iPad to use the camera flow. In Simulator, a placeholder image is shown so the app still runs.", comment: "Instructions for Simulator fallback"))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 24)

                Button(NSLocalizedString("camera.sim.loadPlaceholder", tableName: "Localizable", bundle: .main, value: "Load Placeholder Image", comment: "Load placeholder image button")) {
                    selectedImage = UIImage(systemName: "camera.macro")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(24)
        }
    }
}

struct ARCameraView: UIViewControllerRepresentable {
    @Binding var capturedImage: UIImage?
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> ARCameraViewController {
        let controller = ARCameraViewController()
        controller.onCapture = { image in
            capturedImage = image
            dismiss()
        }
        controller.onCancel = {
            dismiss()
        }
        return controller
    }
    
    func updateUIViewController(_ uiViewController: ARCameraViewController, context: Context) {}
}

class ARCameraViewController: UIViewController, ARSessionDelegate {
    private var arSession: ARSession?
    private var sceneView: ARSCNView!
    private var captureButton: UIButton!
    private var measurementDisplay: UIView!
    private var cancelButton: UIButton!
    private var centerCrosshair: UIView!
    private var centerCircle: UIView!
    private var triangleIndicator: CAShapeLayer!
    
    private var currentDistance: Float = 100.0
    private var currentTemperature: Float = 0.0
    private let targetDistance: Float = 0.35 // 35 cm in meters
    private let distanceTolerance: Float = 0.05 // ±5 cm tolerance
    
    var onCapture: ((UIImage) -> Void)?
    var onCancel: (() -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Check if LiDAR is available
        guard ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) else {
            showAlert(message: NSLocalizedString("camera.lidarUnavailable", tableName: "Localizable", bundle: .main, value: "LiDAR is not available on this device", comment: "Alert shown when LiDAR is unavailable"))
            return
        }
        
        setupARView()
        setupUI()
    }
    
    private func setupARView() {
        sceneView = ARSCNView(frame: view.bounds)
        sceneView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        sceneView.debugOptions = [.showFeaturePoints]
        view.addSubview(sceneView)
        
        arSession = ARSession()
        arSession?.delegate = self
        if let arSession = arSession {
            sceneView.session = arSession
        }
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.sceneReconstruction = .mesh
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics.insert(.sceneDepth)
        }
        configuration.environmentTexturing = .automatic
        
        arSession?.run(configuration)
    }
    
    private func setupUI() {
        // Measurement display at bottom
        measurementDisplay = UIView()
        measurementDisplay.translatesAutoresizingMaskIntoConstraints = false
        measurementDisplay.backgroundColor = UIColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 0.9)
        measurementDisplay.layer.cornerRadius = 12
        measurementDisplay.clipsToBounds = true
        view.addSubview(measurementDisplay)
        
        let displayLabel = UILabel()
        displayLabel.translatesAutoresizingMaskIntoConstraints = false
        displayLabel.textAlignment = .center
        displayLabel.font = .systemFont(ofSize: 28, weight: .bold)
        displayLabel.textColor = .white
        displayLabel.text = String(format: NSLocalizedString("camera.measurement.format", tableName: "Localizable", bundle: .main, value: "%.2f cm", comment: "Format for distance measurement in cm"), 35.00)
        measurementDisplay.addSubview(displayLabel)
        
        // Center crosshair
        centerCrosshair = UIView()
        centerCrosshair.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(centerCrosshair)
        
        let crosshairSize: CGFloat = 80
        let lineWidth: CGFloat = 2
        let cornerSize: CGFloat = 20
        let lineLayers = createCrosshairLines(size: crosshairSize, lineWidth: lineWidth, cornerSize: cornerSize)
        
        for layer in lineLayers {
            centerCrosshair.layer.addSublayer(layer)
        }
        
        // Center circle
        centerCircle = UIView()
        centerCircle.translatesAutoresizingMaskIntoConstraints = false
        centerCircle.layer.borderColor = UIColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1.0).cgColor
        centerCircle.layer.borderWidth = 3
        centerCircle.backgroundColor = .clear
        centerCircle.layer.cornerRadius = 8
        view.addSubview(centerCircle)
        
        // Triangle indicator
        let triangleView = UIView()
        triangleView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(triangleView)
        
        let triangleLayer = createTriangleLayer(size: CGSize(width: 20, height: 20), color: UIColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1.0).cgColor)
        triangleView.layer.addSublayer(triangleLayer)
        
        // Capture button
        captureButton = UIButton(type: .system)
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        captureButton.setTitle(NSLocalizedString("camera.capture", tableName: "Localizable", bundle: .main, value: "Capture", comment: "Capture button"), for: .normal)
        captureButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        captureButton.backgroundColor = .systemGray
        captureButton.setTitleColor(.white, for: .normal)
        captureButton.layer.cornerRadius = 25
        captureButton.isEnabled = false
        captureButton.addTarget(self, action: #selector(capturePhoto), for: .touchUpInside)
        view.addSubview(captureButton)
        
        // Cancel button
        cancelButton = UIButton(type: .system)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.setTitle(NSLocalizedString("common.cancel", tableName: "Localizable", bundle: .main, value: "Cancel", comment: "Cancel button"), for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 16)
        cancelButton.setTitleColor(.white, for: .normal)
        cancelButton.addTarget(self, action: #selector(cancel), for: .touchUpInside)
        view.addSubview(cancelButton)
        
        NSLayoutConstraint.activate([
            // Crosshair
            centerCrosshair.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            centerCrosshair.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            centerCrosshair.widthAnchor.constraint(equalToConstant: 80),
            centerCrosshair.heightAnchor.constraint(equalToConstant: 80),
            
            // Center circle
            centerCircle.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            centerCircle.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            centerCircle.widthAnchor.constraint(equalToConstant: 16),
            centerCircle.heightAnchor.constraint(equalToConstant: 16),
            
            // Triangle
            triangleView.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: 50),
            triangleView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 15),
            triangleView.widthAnchor.constraint(equalToConstant: 20),
            triangleView.heightAnchor.constraint(equalToConstant: 20),
            
            // Measurement display
            measurementDisplay.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            measurementDisplay.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            measurementDisplay.widthAnchor.constraint(equalToConstant: 200),
            measurementDisplay.heightAnchor.constraint(equalToConstant: 70),
            
            // Display labels
            displayLabel.topAnchor.constraint(equalTo: measurementDisplay.topAnchor, constant: 8),
            displayLabel.centerXAnchor.constraint(equalTo: measurementDisplay.centerXAnchor),
            
            // Capture button
            captureButton.bottomAnchor.constraint(equalTo: measurementDisplay.topAnchor, constant: -30),
            captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            captureButton.widthAnchor.constraint(equalToConstant: 200),
            captureButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Cancel button
            cancelButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            cancelButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20)
        ])
    }
    
    private func createCrosshairLines(size: CGFloat, lineWidth: CGFloat, cornerSize: CGFloat) -> [CAShapeLayer] {
        let redColor = UIColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1.0).cgColor
        var layers: [CAShapeLayer] = []
        
        let halfSize = size / 2
        
        // Top-left corner
        let tlPath = UIBezierPath()
        tlPath.move(to: CGPoint(x: 0, y: cornerSize))
        tlPath.addLine(to: CGPoint(x: 0, y: 0))
        tlPath.addLine(to: CGPoint(x: cornerSize, y: 0))
        
        // Top-right corner
        let trPath = UIBezierPath()
        trPath.move(to: CGPoint(x: size - cornerSize, y: 0))
        trPath.addLine(to: CGPoint(x: size, y: 0))
        trPath.addLine(to: CGPoint(x: size, y: cornerSize))
        
        // Bottom-right corner
        let brPath = UIBezierPath()
        brPath.move(to: CGPoint(x: size, y: size - cornerSize))
        brPath.addLine(to: CGPoint(x: size, y: size))
        brPath.addLine(to: CGPoint(x: size - cornerSize, y: size))
        
        // Bottom-left corner
        let blPath = UIBezierPath()
        blPath.move(to: CGPoint(x: cornerSize, y: size))
        blPath.addLine(to: CGPoint(x: 0, y: size))
        blPath.addLine(to: CGPoint(x: 0, y: size - cornerSize))
        
        for path in [tlPath, trPath, brPath, blPath] {
            let layer = CAShapeLayer()
            layer.path = path.cgPath
            layer.strokeColor = redColor
            layer.lineWidth = lineWidth
            layer.fillColor = UIColor.clear.cgColor
            layer.position = CGPoint(x: halfSize - size/2, y: halfSize - size/2)
            layers.append(layer)
        }
        
        return layers
    }
    
    private func createTriangleLayer(size: CGSize, color: CGColor) -> CAShapeLayer {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: size.width / 2, y: 0))
        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.addLine(to: CGPoint(x: 0, y: size.height))
        path.close()
        
        let layer = CAShapeLayer()
        layer.path = path.cgPath
        layer.fillColor = color
        return layer
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard sceneView != nil else { return }

        // Try to get the closest distance from the LiDAR depth map
        if let sceneDepth = frame.sceneDepth {
            let depthMap = sceneDepth.depthMap
            CVPixelBufferLockBaseAddress(depthMap, .readOnly)
            
            if let baseAddress = CVPixelBufferGetBaseAddress(depthMap) {
                let width = CVPixelBufferGetWidth(depthMap)
                let height = CVPixelBufferGetHeight(depthMap)
                let bytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)
                
                var minDistanceInFrame: Float = Float.greatestFiniteMagnitude
                
                // Iterate over the depth map to find the closest point
                for y in 0..<height {
                    let rowData = baseAddress.advanced(by: y * bytesPerRow)
                    let rowPtr = rowData.assumingMemoryBound(to: Float32.self)
                    
                    for x in 0..<width {
                        let depth = rowPtr[x]
                        // Filter noise: valid depth (>0) and not unreasonably close (<5cm)
                        if depth > 0.05 && depth < minDistanceInFrame {
                            minDistanceInFrame = depth
                        }
                    }
                }
                
                if minDistanceInFrame < Float.greatestFiniteMagnitude {
                    currentDistance = minDistanceInFrame
                    DispatchQueue.main.async { [weak self] in
                        self?.updateMeasurementDisplay()
                    }
                }
            }
            CVPixelBufferUnlockBaseAddress(depthMap, .readOnly)
            return
        }

        // Fallback: Raycast from center if depth map is unavailable
        let screenCenter = CGPoint(x: sceneView.bounds.midX, y: sceneView.bounds.midY)
        if let query = sceneView.raycastQuery(from: screenCenter, allowing: .estimatedPlane, alignment: .any),
           let arSession = arSession {
            let results = arSession.raycast(query)
            if let result = results.first {
                let hitTransform = result.worldTransform
                let hitPosition = SIMD3<Float>(hitTransform.columns.3.x, hitTransform.columns.3.y, hitTransform.columns.3.z)
                let cameraTransform = frame.camera.transform
                let cameraPosition = SIMD3<Float>(cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z)
                currentDistance = simd_distance(cameraPosition, hitPosition)
                
                DispatchQueue.main.async { [weak self] in
                    self?.updateMeasurementDisplay()
                }
            }
        }
    }
    
    private func updateMeasurementDisplay() {
        let distanceInCm = self.currentDistance * 100
        
        // Get the measurement display label and update it
        if let displayLabel = measurementDisplay.subviews.first(where: { $0 is UILabel }) as? UILabel {
            displayLabel.text = String(format: NSLocalizedString("camera.measurement.format", tableName: "Localizable", bundle: .main, value: "%.2f cm", comment: "Format for distance measurement in cm"), distanceInCm)
        }
        
        // Enable button if within target range
        let isInRange = abs(self.currentDistance - self.targetDistance) <= self.distanceTolerance
        
        self.captureButton.isEnabled = isInRange
        self.captureButton.backgroundColor = isInRange ? .systemGreen : .systemGray
        
        // Update measurement display color based on accuracy
        self.measurementDisplay.backgroundColor = isInRange ?
            UIColor(red: 0.2, green: 0.8, blue: 0.3, alpha: 0.9) :
            UIColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 0.9)
    }
    
    @objc private func capturePhoto() {
        guard sceneView != nil else { return }
        let image = sceneView.snapshot()
        onCapture?(image)
    }
    
    @objc private func cancel() {
        onCancel?()
    }
    
    private func showAlert(message: String) {
        let alert = UIAlertController(title: NSLocalizedString("common.error.title", tableName: "Localizable", bundle: .main, value: "Error", comment: "Generic error title"), message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("common.ok", tableName: "Localizable", bundle: .main, value: "OK", comment: "OK button"), style: .default) { [weak self] _ in
            self?.onCancel?()
        })
        present(alert, animated: true)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        arSession?.pause()
    }
}

