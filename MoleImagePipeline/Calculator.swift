import UIKit
import CoreVideo
import simd

/// Parent class for physical mole measurement.
///
/// `Calculator` owns the shared sampling types, the static sampling helpers,
/// and the full `calculateMetrics` pipeline (prepare → gather samples →
/// compute measurement). Concrete strategies (`CalculatorLinear`,
/// `CalculatorProjection`) inherit from this class and plug in their
/// strategy-specific measurement math by overriding `computeMeasurement`.
/// A shared default `samplePixels` implementation is provided, and a
/// `Model`-based routing overload lets callers pick a strategy by enum
/// instead of instantiating a subclass directly.
class Calculator {

    /// Which measurement model `calculateMetrics` should run.
    enum Model {
        /// Distance-lookup based sizing using median depth.
        case linear
        /// Pinhole projection based sizing using ARKit camera intrinsics.
        case projection
    }

    // MARK: - Shared types

    /// Locked-buffer view of a depth map passed into the sampling loop.
    struct DepthBufferView {
        let base: UnsafeMutableRawPointer
        let width: Int
        let height: Int
        let bytesPerRow: Int
    }

    /// Locked-buffer view of an optional confidence map passed into the sampling loop.
    struct ConfidenceBufferView {
        let base: UnsafeMutableRawPointer
        let bytesPerRow: Int
    }

    /// Preprocessed mask and geometry shared by all sampling passes.
    struct SamplingContext {
        let mask: (pixels: [UInt8], width: Int, height: Int)
        let bounds: (minX: Int, minY: Int, maxX: Int, maxY: Int)
        let sensorWidth: Int
        let sensorHeight: Int
    }

    /// Per-pixel data extracted from the selected mask region and aligned depth map.
    struct MoleSamples {
        /// Pixel coordinates in normalized image space.
        var points: [CGPoint]
        /// Mask probability per entry in `points`, derived from alpha.
        var weights: [Double]
        /// Deduplicated valid depth samples in meters.
        var depths: [Float]
    }

    /// Physical mole measurements returned in millimeter units.
    struct MoleMeasurement {
        /// Estimated area in square millimeters.
        let areaMM2: CGFloat

        /// Estimated diameter in millimeters.
        let diameterMM: CGFloat

        static let zero = MoleMeasurement(areaMM2: 0, diameterMM: 0)
    }

    let distanceLookup: DistanceLookup = .default

    // MARK: - Routing

    /// Computes area and diameter using the selected measurement model.
    ///
    /// Instantiates the matching subclass and forwards the call to the
    /// inherited `calculateMetrics`. Callers needing custom dependencies
    /// (e.g. a mocked `DistanceLookup`) should construct the subclass
    /// directly instead of going through this router.
    ///
    /// - Parameters:
    ///   - segmentedImage: Tuple containing the mask image and selected bounding box.
    ///   - depthMap: Float32 scene depth map in meters.
    ///   - confidenceMap: Optional scene depth confidence map.
    ///   - cameraIntrinsics: ARKit camera intrinsics; required for `.projection`, ignored for `.linear`.
    ///   - imageOrientation: Orientation of the captured image before normalization.
    ///   - model: Which strategy should run.
    /// - Returns: A `MoleMeasurement`. Fields are `0` when required data is unavailable.
    func calculateMetrics(
        from segmentedImage: (UIImage, [CGRect]),
        depthMap: CVPixelBuffer?,
        confidenceMap: CVPixelBuffer?,
        cameraIntrinsics: simd_float3x3? = nil,
        imageOrientation: UIImage.Orientation = .up,
        model: Model
    ) -> MoleMeasurement {

        guard let samples = gatherMoleSamples(
            from: segmentedImage,
            depthMap: depthMap,
            confidenceMap: confidenceMap,
            imageOrientation: imageOrientation
        ) else {
            return .zero
        }
        guard !samples.depths.isEmpty else { return .zero }

        let strategy: Calculator
        switch model {
        case .linear:     strategy = CalculatorLinear()
        case .projection: strategy = CalculatorProjection()
        }
        return strategy.measure(from: samples, cameraIntrinsics: cameraIntrinsics)
    }

    /// Strategy hook: turn samples into a physical measurement.
    ///
    /// Subclasses derive their own scaling details (mm/pixel for linear,
    /// validated intrinsics for projection) and return the final measurement.
    func measure(from samples: MoleSamples, cameraIntrinsics: simd_float3x3?) -> MoleMeasurement {
        fatalError("Subclasses must override measure(from:cameraIntrinsics:)")
    }

    // MARK: - Shared measurement pipeline

    /// Samples mask pixels and aligned depth values inside the selected box.
    ///
    /// Shared orchestration — prepares the sampling context, locks the depth and
    /// confidence buffers, then runs the shared per-pixel traversal.
    func gatherMoleSamples(
        from segmentedImage: (UIImage, [CGRect]),
        depthMap: CVPixelBuffer?,
        confidenceMap: CVPixelBuffer?,
        imageOrientation: UIImage.Orientation
    ) -> MoleSamples? {
        guard let depthMap = depthMap,
              let context = Calculator.prepareSamplingContext(
                from: segmentedImage,
                imageOrientation: imageOrientation
              ) else {
            return nil
        }

        return Calculator.withLockedBuffers(depthMap: depthMap, confidenceMap: confidenceMap) { depth, confidence in
            self.samplePixels(
                context: context,
                depth: depth,
                confidence: confidence,
                orientation: imageOrientation
            )
        }
    }

    // MARK: - Strategy hooks

    /// Walks the bounding box and collects weighted mask points plus aligned depth samples.
    ///
    /// Default behavior matches the projection sampling rule:
    /// mask pixels are retained even when their mapped depth sample is invalid,
    /// while depth values are deduplicated per depth pixel.
    ///
    /// Subclasses may override when they need a different acceptance rule.
    func samplePixels(
        context: SamplingContext,
        depth: DepthBufferView,
        confidence: ConfidenceBufferView?,
        orientation: UIImage.Orientation
    ) -> MoleSamples {
        let alphaScale = Double(SegmentationRendererValues.maskAlphaMax) * SegmentationRendererValues.alphaByteScale

        var points: [CGPoint] = []
        var weights: [Double] = []
        var depths: [Float] = []
        var sampledDepthPixels = Set<Int>()

        let mask = context.mask
        let bounds = context.bounds

        let estimatedPixelCount = max(0, (bounds.maxX - bounds.minX + 1) * (bounds.maxY - bounds.minY + 1))
        points.reserveCapacity(estimatedPixelCount)
        weights.reserveCapacity(estimatedPixelCount)
        depths.reserveCapacity(min(estimatedPixelCount, depth.width * depth.height))

        for ny in bounds.minY...bounds.maxY {
            for nx in bounds.minX...bounds.maxX {
                let pixelOffset = (ny * mask.width + nx) * LesionSizingConstants.rgbaBytesPerPixel
                let alpha = mask.pixels[pixelOffset + LesionSizingConstants.alphaChannelOffset]
                guard alpha >= LesionSizingConstants.minimumMaskAlpha else { continue }

                points.append(CGPoint(x: nx, y: ny))
                weights.append(min(1.0, Double(alpha) / alphaScale))

                let (sx, sy) = CalculatorHelper.normalizedToSensor(
                    nx: nx, ny: ny,
                    normalizedWidth: mask.width, normalizedHeight: mask.height,
                    orientation: orientation
                )

                let dx = sx * depth.width / context.sensorWidth
                let dy = sy * depth.height / context.sensorHeight
                guard dx >= 0 && dx < depth.width && dy >= 0 && dy < depth.height else { continue }

                let depthIndex = dy * depth.width + dx
                guard !sampledDepthPixels.contains(depthIndex) else { continue }
                sampledDepthPixels.insert(depthIndex)

                if let value = Calculator.sampleDepth(x: dx, y: dy, depth: depth, confidence: confidence) {
                    depths.append(value)
                }
            }
        }

        return MoleSamples(points: points, weights: weights, depths: depths)
    }

    // MARK: - Shared sampling helpers

    /// Renders the mask, computes sensor dimensions, and clamps the bounding box.
    ///
    /// - Parameters:
    ///   - segmentedImage: Tuple containing the mask image and selected bounding box.
    ///   - imageOrientation: Orientation of the captured image before normalization.
    /// - Returns: A `SamplingContext`, or `nil` when required inputs are missing or invalid.
    static func prepareSamplingContext(
        from segmentedImage: (UIImage, [CGRect]),
        imageOrientation: UIImage.Orientation
    ) -> SamplingContext? {
        guard let box = segmentedImage.1.first,
              let renderedMask = CalculatorHelper.renderToRGBA(image: segmentedImage.0) else {
            return nil
        }

        let (sensorW, sensorH) = CalculatorHelper.sensorDimensions(
            normalizedWidth: renderedMask.width,
            normalizedHeight: renderedMask.height,
            orientation: imageOrientation
        )
        guard sensorW > 0 && sensorH > 0 else { return nil }

        guard let bounds = CalculatorHelper.clampedPixelBounds(
            for: box,
            width: renderedMask.width,
            height: renderedMask.height
        ) else {
            return nil
        }

        return SamplingContext(
            mask: renderedMask,
            bounds: bounds,
            sensorWidth: sensorW,
            sensorHeight: sensorH
        )
    }

    /// Locks the depth and optional confidence buffers for the lifetime of `body`.
    ///
    /// The inner closure receives typed views into the locked buffers; the raw
    /// pointers are guaranteed to be valid for the duration of the call.
    /// 
    /// - Parameters:
    ///   - depthMap: Depth map to lock; must be non-`nil` and valid.
    ///   - confidenceMap: Optional confidence map to lock alongside the depth map.
    ///   - body: Closure to execute while buffers are locked. Receives typed views of
    /// - Returns: The closure's return value, or `nil` if the depth base address cannot be retrieved.
    static func withLockedBuffers<Result>(
        depthMap: CVPixelBuffer,
        confidenceMap: CVPixelBuffer?,
        _ body: (DepthBufferView, ConfidenceBufferView?) -> Result
    ) -> Result? {
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }

        guard let depthBase = CVPixelBufferGetBaseAddress(depthMap) else { return nil }
        let depth = DepthBufferView(
            base: depthBase,
            width: CVPixelBufferGetWidth(depthMap),
            height: CVPixelBufferGetHeight(depthMap),
            bytesPerRow: CVPixelBufferGetBytesPerRow(depthMap)
        )

        var confidence: ConfidenceBufferView?
        if let confidenceMap = confidenceMap {
            CVPixelBufferLockBaseAddress(confidenceMap, .readOnly)
            if let confBase = CVPixelBufferGetBaseAddress(confidenceMap) {
                confidence = ConfidenceBufferView(
                    base: confBase,
                    bytesPerRow: CVPixelBufferGetBytesPerRow(confidenceMap)
                )
            }
        }
        defer {
            if let confidenceMap = confidenceMap {
                CVPixelBufferUnlockBaseAddress(confidenceMap, .readOnly)
            }
        }

        return body(depth, confidence)
    }

    /// Reads one depth pixel, rejecting it when confidence is too low or the depth is out of range.
    ///
    /// - Parameters:
    ///   - dx: X coordinate in the depth map.
    ///   - dy: Y coordinate in the depth map.
    ///   - depth: Locked-buffer view of the depth map.
    ///   - confidence: Optional locked-buffer view of the confidence map.
    /// - Returns: A valid depth value in meters, or `nil` if the pixel is invalid or unreliable.
    static func sampleDepth(
        x dx: Int,
        y dy: Int,
        depth: DepthBufferView,
        confidence: ConfidenceBufferView?
    ) -> Float? {
        if let confidence = confidence {
            let confPtr = confidence.base.advanced(by: dy * confidence.bytesPerRow)
                .assumingMemoryBound(to: UInt8.self)
            guard confPtr[dx] >= LesionSizingConstants.minimumAcceptedDepthConfidence else { return nil }
        }

        let depthPtr = depth.base.advanced(by: dy * depth.bytesPerRow)
            .assumingMemoryBound(to: Float32.self)
        let value = depthPtr[dx]
        guard LesionSizingConstants.validDepthRangeMeters.contains(value) else { return nil }
        return value
    }
}
