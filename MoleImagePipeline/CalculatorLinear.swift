import UIKit
import CoreVideo

/// Computes physical mole measurements using a linear distance→mm/pixel model.
///
/// The projection-based `Calculator` requires camera intrinsics to convert
/// pixel counts into physical units. This class replaces that step with a
/// `DistanceLookup`: the median depth of the lesion samples is mapped through
/// the calibration table to obtain a single millimeters-per-pixel factor,
/// which is then applied to both area and diameter.
class CalculatorLinear {

    /// Per-pixel data extracted from the selected mask region and depth map.
    private struct MoleSamples {
        /// Pixel coordinates in normalized image space.
        var points: [CGPoint]
        /// Mask probability per entry in `points`, derived from alpha.
        var weights: [Double]
        /// Deduplicated valid depth samples in meters.
        var depths: [Float]
    }

    /// Locked-buffer view of a depth map passed into the sampling loop.
    private struct DepthBufferView {
        let base: UnsafeMutableRawPointer
        let width: Int
        let height: Int
        let bytesPerRow: Int
    }

    /// Locked-buffer view of an optional confidence map passed into the sampling loop.
    private struct ConfidenceBufferView {
        let base: UnsafeMutableRawPointer
        let bytesPerRow: Int
    }

    /// Physical mole measurements returned in millimeter units.
    struct LinearMoleMeasurement {
        /// Estimated area in square millimeters.
        let areaMM2: CGFloat

        /// Estimated Feret diameter in millimeters.
        let diameterMM: CGFloat
    }

    /// Calibration table driving the pixel→millimeter conversion.
    let distanceLookup: DistanceLookup

    init(distanceLookup: DistanceLookup = .default) {
        self.distanceLookup = distanceLookup
    }

    /// Computes area and diameter from one shared sampling pass.
    ///
    /// - Parameters:
    ///   - segmentedImage: Tuple containing the mask image and selected bounding box.
    ///   - depthMap: Float32 scene depth map in meters.
    ///   - confidenceMap: Optional scene depth confidence map.
    ///   - imageOrientation: Orientation of the captured image before normalization.
    /// - Returns: A `LinearMoleMeasurement`. Fields are `0` when required data is unavailable.
    func calculateMetrics(
        from segmentedImage: (UIImage, [CGRect]),
        depthMap: CVPixelBuffer?,
        confidenceMap: CVPixelBuffer?,
        imageOrientation: UIImage.Orientation = .up
    ) -> LinearMoleMeasurement {
        guard let samples = gatherMoleSamples(
            from: segmentedImage,
            depthMap: depthMap,
            confidenceMap: confidenceMap,
            imageOrientation: imageOrientation
        ), !samples.depths.isEmpty else {
            return LinearMoleMeasurement(areaMM2: 0, diameterMM: 0)
        }

        // Median depth damps the impact of outlier depth pixels, matching the
        // robustness guarantees of the projection-based calculator.
        let medianDepth = CalculatorHelper.median(of: samples.depths)
        let mmPerPixel = distanceLookup.mmPerPixel(atDistance: medianDepth)

        return LinearMoleMeasurement(
            areaMM2: computeAreaMM2(from: samples, mmPerPixel: mmPerPixel),
            diameterMM: computeDiameterMM(from: samples, mmPerPixel: mmPerPixel)
        )
    }

    // MARK: - Sampling

    /// Samples mask pixels and aligned depth values inside the selected box.
    ///
    /// - Parameters:
    ///   - segmentedImage: Tuple containing the mask image and selected bounding box.
    ///   - depthMap: Float32 scene depth map in meters.
    ///   - confidenceMap: Optional scene depth confidence map.
    ///   - imageOrientation: Orientation of the captured image before normalization.
    /// - Returns: A `MoleSamples` payload, or `nil` when required inputs are missing or invalid.
    private func gatherMoleSamples(
        from segmentedImage: (UIImage, [CGRect]),
        depthMap: CVPixelBuffer?,
        confidenceMap: CVPixelBuffer?,
        imageOrientation: UIImage.Orientation
    ) -> MoleSamples? {
        guard let depthMap = depthMap,
              let box = segmentedImage.1.first else {
            return nil
        }

        guard let renderedMask = CalculatorHelper.renderToRGBA(image: segmentedImage.0) else { return nil }

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

        return samplePixels(
            mask: renderedMask,
            bounds: bounds,
            depth: depth,
            confidence: confidence,
            sensorWidth: sensorW,
            sensorHeight: sensorH,
            orientation: imageOrientation
        )
    }

    /// Walks the bounding box, collecting weighted mask points and aligned depth samples.
    private func samplePixels(
        mask: (pixels: [UInt8], width: Int, height: Int),
        bounds: (minX: Int, minY: Int, maxX: Int, maxY: Int),
        depth: DepthBufferView,
        confidence: ConfidenceBufferView?,
        sensorWidth: Int,
        sensorHeight: Int,
        orientation: UIImage.Orientation
    ) -> MoleSamples {
        let alphaScale = Double(SegmentationRendererValues.maskAlphaMax) * SegmentationRendererValues.alphaByteScale

        var points: [CGPoint] = []
        var weights: [Double] = []
        var depths: [Float] = []
        var sampledDepthPixels = Set<Int>()
        var validDepthPixels = Set<Int>()

        let estimatedPixelCount = max(0, (bounds.maxX - bounds.minX + 1) * (bounds.maxY - bounds.minY + 1))
        points.reserveCapacity(estimatedPixelCount)
        weights.reserveCapacity(estimatedPixelCount)
        depths.reserveCapacity(min(estimatedPixelCount, depth.width * depth.height))

        for ny in bounds.minY...bounds.maxY {
            for nx in bounds.minX...bounds.maxX {
                let pixelOffset = (ny * mask.width + nx) * LesionSizingConstants.rgbaBytesPerPixel
                let alpha = mask.pixels[pixelOffset + LesionSizingConstants.alphaChannelOffset]
                guard alpha >= LesionSizingConstants.minimumMaskAlpha else { continue }

                let (sx, sy) = CalculatorHelper.normalizedToSensor(
                    nx: nx, ny: ny,
                    normalizedWidth: mask.width, normalizedHeight: mask.height,
                    orientation: orientation
                )

                let dx = sx * depth.width / sensorWidth
                let dy = sy * depth.height / sensorHeight
                guard dx >= 0 && dx < depth.width && dy >= 0 && dy < depth.height else { continue }

                let depthIndex = dy * depth.width + dx

                var hasValidDepthCoverage = validDepthPixels.contains(depthIndex)
                if !hasValidDepthCoverage {
                    guard !sampledDepthPixels.contains(depthIndex) else { continue }
                    sampledDepthPixels.insert(depthIndex)

                    if let value = sampleDepth(atX: dx, y: dy, depth: depth, confidence: confidence) {
                        depths.append(value)
                        validDepthPixels.insert(depthIndex)
                        hasValidDepthCoverage = true
                    }
                }

                guard hasValidDepthCoverage else { continue }

                points.append(CGPoint(x: nx, y: ny))
                weights.append(min(1.0, Double(alpha) / alphaScale))
            }
        }

        return MoleSamples(points: points, weights: weights, depths: depths)
    }

    /// Reads one depth pixel, rejecting it when confidence is too low or the depth is out of range.
    private func sampleDepth(
        atX dx: Int,
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

    // MARK: - Measurement

    /// Computes area in mm² using the linear mm-per-pixel factor.
    private func computeAreaMM2(from samples: MoleSamples, mmPerPixel: Double) -> CGFloat {
        let weightedPixelCount = samples.weights.reduce(0, +)
        guard weightedPixelCount > 0 else { return 0.0 }
        print("Computing area from \(samples.points.count) points, total weight = \(weightedPixelCount), mmPerPixel = \(mmPerPixel)")
        
        // Each pixel represents a square of side `mmPerPixel` millimeters.
        let areaSquareMM = weightedPixelCount * mmPerPixel * mmPerPixel
        return CGFloat(areaSquareMM)
    }

    /// Computes Feret-style diameter in mm using the linear mm-per-pixel factor.
    private func computeDiameterMM(from samples: MoleSamples, mmPerPixel: Double) -> CGFloat {
        guard samples.points.count >= LesionSizingConstants.minimumDiameterPointCount else {
            return 0.0
        }
        print("Computing diameter from \(samples.points.count) points and mmPerPixel = \(mmPerPixel)")
        let hull = CalculatorHelper.convexHull(of: samples.points)
        let maxSquaredPixels = CalculatorLinearHelper.maxPairwiseSquaredPixelDistance(in: hull)

        let diameterMM = sqrt(maxSquaredPixels) * mmPerPixel
        return CGFloat(diameterMM)
    }
}
