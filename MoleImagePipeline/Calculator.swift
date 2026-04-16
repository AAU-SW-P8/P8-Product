import UIKit
import CoreVideo
import simd

/// Computes physical mole measurements from a segmentation mask, depth map,
/// and camera intrinsics.
class Calculator {

    /// Per-pixel data extracted from the selected mask region and aligned depth map.
    private struct MoleSamples {
        /// Pixel coordinates in normalized image space.
        var points: [CGPoint]
        /// Mask probability per entry in `points`, derived from alpha.
        var weights: [Double]
        /// Deduplicated valid depth samples in meters.
        var depths: [Float]
        /// Camera focal lengths in pixels.
        var fx: Double
        var fy: Double
    }

    /// Physical mole measurements returned in millimeter units.
    struct MoleMeasurement {
        /// Estimated area in square millimeters.
        let areaMM2: CGFloat

        /// Estimated Feret diameter in millimeters.
        let diameterMM: CGFloat
    }

    /// Computes area and diameter from one shared sampling pass.
    ///
    /// - Parameters:
    ///   - segmentedImage: Tuple containing the mask image and selected bounding box.
    ///   - depthMap: Float32 scene depth map in meters.
    ///   - confidenceMap: Optional scene depth confidence map.
    ///   - cameraIntrinsics: Camera intrinsics matrix from ARKit.
    ///   - imageOrientation: Orientation of the captured image before normalization.
    /// - Returns: A `MoleMeasurement`. Fields are `0` when required data is unavailable.
    func calculateMetrics(
        from segmentedImage: (UIImage, [CGRect]),
        depthMap: CVPixelBuffer?,
        confidenceMap: CVPixelBuffer?,
        cameraIntrinsics: simd_float3x3? = nil,
        imageOrientation: UIImage.Orientation = .up
    ) -> MoleMeasurement {
        guard let samples = gatherMoleSamples(
            from: segmentedImage,
            depthMap: depthMap,
            confidenceMap: confidenceMap,
            cameraIntrinsics: cameraIntrinsics,
            imageOrientation: imageOrientation
        ) else {
            return MoleMeasurement(areaMM2: 0, diameterMM: 0)
        }

        return MoleMeasurement(
            areaMM2: computeAreaMM2(from: samples),
            diameterMM: computeDiameterMM(from: samples)
        )
    }

    /// Calculates mole area in mm².
    ///
    /// - Parameters:
    ///   - segmentedImage: Tuple containing the mask image and selected bounding box.
    ///   - depthMap: Float32 scene depth map in meters.
    ///   - confidenceMap: Optional scene depth confidence map.
    ///   - cameraIntrinsics: Camera intrinsics matrix from ARKit.
    ///   - imageOrientation: Orientation of the captured image before normalization.
    /// - Returns: Area in mm², or `0` when required data is unavailable.
    func calculateArea(
        from segmentedImage: (UIImage, [CGRect]),
        depthMap: CVPixelBuffer?,
        confidenceMap: CVPixelBuffer?,
        cameraIntrinsics: simd_float3x3? = nil,
        imageOrientation: UIImage.Orientation = .up
    ) -> CGFloat {
        calculateMetrics(
            from: segmentedImage,
            depthMap: depthMap,
            confidenceMap: confidenceMap,
            cameraIntrinsics: cameraIntrinsics,
            imageOrientation: imageOrientation
        ).areaMM2
    }

    /// Estimates mole diameter in mm using the largest hull-to-hull pixel distance.
    ///
    /// Parameters mirror `calculateArea`.
    /// - Returns: Diameter in mm, or `0` when required data is unavailable.
    func calculateDiameter(
        from segmentedImage: (UIImage, [CGRect]),
        depthMap: CVPixelBuffer?,
        confidenceMap: CVPixelBuffer?,
        cameraIntrinsics: simd_float3x3? = nil,
        imageOrientation: UIImage.Orientation = .up
    ) -> CGFloat {
        calculateMetrics(
            from: segmentedImage,
            depthMap: depthMap,
            confidenceMap: confidenceMap,
            cameraIntrinsics: cameraIntrinsics,
            imageOrientation: imageOrientation
        ).diameterMM
    }

    // MARK: - Sampling

    /// Samples mask pixels and aligned depth values inside the selected box.
    ///
    /// - Parameters:
    ///   - segmentedImage: Tuple containing the mask image and selected bounding box.
    ///   - depthMap: Float32 scene depth map in meters.
    ///   - confidenceMap: Optional scene depth confidence map.
    ///   - cameraIntrinsics: Camera intrinsics matrix from ARKit.
    ///   - imageOrientation: Orientation of the captured image before normalization.
    /// - Returns: A `MoleSamples` payload, or `nil` when required inputs are missing or invalid.
    private func gatherMoleSamples(
        from segmentedImage: (UIImage, [CGRect]),
        depthMap: CVPixelBuffer?,
        confidenceMap: CVPixelBuffer?,
        cameraIntrinsics: simd_float3x3?,
        imageOrientation: UIImage.Orientation
    ) -> MoleSamples? {
        guard let depthMap = depthMap,
              let intrinsics = cameraIntrinsics,
              let box = segmentedImage.1.first else {
            return nil
        }

        let fx = intrinsics[0][0]
        let fy = intrinsics[1][1]
        guard fx > 0 && fy > 0 else { return nil }

        guard let renderedMask = CalculatorHelper.renderToRGBA(image: segmentedImage.0) else { return nil }
        let maskPixels = renderedMask.pixels
        let maskW = renderedMask.width
        let maskH = renderedMask.height

        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
        guard let depthBase = CVPixelBufferGetBaseAddress(depthMap) else { return nil }
        let depthW = CVPixelBufferGetWidth(depthMap)
        let depthH = CVPixelBufferGetHeight(depthMap)
        let depthBytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)

        let confBase: UnsafeMutableRawPointer?
        let confBytesPerRow: Int
        if let confidenceMap = confidenceMap {
            CVPixelBufferLockBaseAddress(confidenceMap, .readOnly)
            confBase = CVPixelBufferGetBaseAddress(confidenceMap)
            confBytesPerRow = CVPixelBufferGetBytesPerRow(confidenceMap)
        } else {
            confBase = nil
            confBytesPerRow = 0
        }
        defer {
            if let confidenceMap = confidenceMap {
                CVPixelBufferUnlockBaseAddress(confidenceMap, .readOnly)
            }
        }

        let (sensorW, sensorH) = CalculatorHelper.sensorDimensions(
            normalizedWidth: maskW,
            normalizedHeight: maskH,
            orientation: imageOrientation
        )
        guard sensorW > 0 && sensorH > 0 else { return nil }

        guard let bounds = CalculatorHelper.clampedPixelBounds(for: box, width: maskW, height: maskH) else {
            return nil
        }

        let alphaScale = Double(SegmentationRendererValues.maskAlphaMax) * SegmentationRendererValues.alphaByteScale
        var points: [CGPoint] = []
        var weights: [Double] = []
        var depths: [Float] = []
        var sampledDepthPixels = Set<Int>()

        let estimatedPixelCount = max(0, (bounds.maxX - bounds.minX + 1) * (bounds.maxY - bounds.minY + 1))
        points.reserveCapacity(estimatedPixelCount)
        weights.reserveCapacity(estimatedPixelCount)
        depths.reserveCapacity(min(estimatedPixelCount, depthW * depthH))

        for ny in bounds.minY...bounds.maxY {
            for nx in bounds.minX...bounds.maxX {
                let pixelOffset = (ny * maskW + nx) * CalculatorValues.rgbaBytesPerPixel
                let alpha = maskPixels[pixelOffset + CalculatorValues.alphaChannelOffset]
                guard alpha >= CalculatorValues.minimumMaskAlpha else { continue }

                points.append(CGPoint(x: nx, y: ny))
                weights.append(min(1.0, Double(alpha) / alphaScale))

                let (sx, sy) = CalculatorHelper.normalizedToSensor(
                    nx: nx, ny: ny,
                    normalizedWidth: maskW, normalizedHeight: maskH,
                    orientation: imageOrientation
                )

                let dx = sx * depthW / sensorW
                let dy = sy * depthH / sensorH
                guard dx >= 0 && dx < depthW && dy >= 0 && dy < depthH else { continue }

                let depthIndex = dy * depthW + dx
                guard !sampledDepthPixels.contains(depthIndex) else { continue }
                sampledDepthPixels.insert(depthIndex)

                if let confBase = confBase {
                    let confPtr = confBase.advanced(by: dy * confBytesPerRow)
                        .assumingMemoryBound(to: UInt8.self)
                    let confidence = confPtr[dx]
                    guard confidence >= CalculatorValues.minimumAcceptedDepthConfidence else { continue }
                }

                let depthPtr = depthBase.advanced(by: dy * depthBytesPerRow)
                    .assumingMemoryBound(to: Float32.self)
                let depth = depthPtr[dx]
                guard CalculatorValues.validDepthRangeMeters.contains(depth) else { continue }

                depths.append(depth)
            }
        }

        return MoleSamples(
            points: points,
            weights: weights,
            depths: depths,
            fx: Double(fx),
            fy: Double(fy)
        )
    }

    /// Computes area in mm² from sampled mask weights and depth values.
    ///
    /// - Parameter samples: Gathered mole samples for the current selection.
    /// - Returns: Area in mm², or `0` when depth or weights are insufficient.
    private func computeAreaMM2(from samples: MoleSamples) -> CGFloat {
        let weightedPixelCount = samples.weights.reduce(0, +)
        guard !samples.depths.isEmpty, weightedPixelCount > 0 else { return 0.0 }

        let depthMeters = CalculatorHelper.median(of: samples.depths)
        let areaSquareMeters = weightedPixelCount * (depthMeters * depthMeters) / (samples.fx * samples.fy)
        return CGFloat(areaSquareMeters * CalculatorValues.squareMetersToSquareMillimeters)
    }

    /// Computes Feret-style diameter in mm from sampled points and depth values.
    ///
    /// - Parameter samples: Gathered mole samples for the current selection.
    /// - Returns: Diameter in mm, or `0` when depth/points are insufficient.
    private func computeDiameterMM(from samples: MoleSamples) -> CGFloat {
        guard !samples.depths.isEmpty,
              samples.points.count >= CalculatorValues.minimumDiameterPointCount else {
            return 0.0
        }

        let depthMeters = CalculatorHelper.median(of: samples.depths)
        let hull = CalculatorHelper.convexHull(of: samples.points)

        let maxSquaredDistance = CalculatorHelper.maxPairwiseSquaredDistance(
            in: hull,
            invFx: 1.0 / samples.fx,
            invFy: 1.0 / samples.fy
        )

        let diameterMeters = sqrt(maxSquaredDistance) * depthMeters
        return CGFloat(diameterMeters * CalculatorValues.metersToMillimeters)
    }

}
