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
    ///
    /// The camera intrinsics matrix (simd_float3x3) representing the pinhole camera model.
    ///
    /// In Swift, this matrix is stored in column-major order and mathematically represents:
    ///
    /// [ fx 0 cx ]
    /// [ 0 fy cy ]
    /// [ 0 0 1 ]
    ///
    /// - fx, fy: The focal length of the camera lens, measured in pixels.
    /// - cx, cy: The principal point (optical center) of the image, measured in pixels.
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

        // Validate intrinsics to avoid propagating bad focal lengths into the area/diameter calculations.
        let fx = intrinsics[0][0]
        let fy = intrinsics[1][1]
        guard fx > 0 && fy > 0 else { return nil }

        guard let renderedMask = CalculatorHelper.renderToRGBA(image: segmentedImage.0) else { return nil }

        // Precompute sensor-aligned dimensions to avoid redundant calculations in the sampling loop.
        let (sensorW, sensorH) = CalculatorHelper.sensorDimensions(
            normalizedWidth: renderedMask.width,
            normalizedHeight: renderedMask.height,
            orientation: imageOrientation
        )
        guard sensorW > 0 && sensorH > 0 else { return nil }

        // Clamp the sampling bounds to the mask dimensions to avoid out-of-bounds access.
        guard let bounds = CalculatorHelper.clampedPixelBounds(
            for: box,
            width: renderedMask.width,
            height: renderedMask.height
        ) else {
            return nil
        }

        // Lock the depth and confidence maps for readOnly access for the lifetime of the sampling pass.
        // This prevents concurrent updates from corrupting samples and ensures thread safety.
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

        // samplePixels has to be called inside the depth/confidence lock scope 
        // to ensure the raw pointers remain valid for the duration of sampling.
        return samplePixels(
            mask: renderedMask,
            bounds: bounds,
            depth: depth,
            confidence: confidence,
            sensorWidth: sensorW,
            sensorHeight: sensorH,
            orientation: imageOrientation,
            fx: Double(fx),
            fy: Double(fy)
        )
    }

    /// Walks the bounding box, collecting weighted mask points and their aligned depth samples.
    ///
    /// Sensor→depth mapping is necessary because the captured image (used for segmentation) and the
    /// depth map can differ in resolution and orientation; this mapping picks the depth value that
    /// actually corresponds to each mask pixel.
    /// - Parameters:
    ///   - mask: RGBA pixel buffer of the segmented mask image.
    ///   - bounds: Clamped bounding box of the selected lesion in pixel coordinates.
    ///   - depth: Locked-buffer view of the depth map.
    ///   - confidence: Optional locked-buffer view of the confidence map.
    ///   - sensorWidth: Width of the camera sensor in pixels.
    ///   - sensorHeight: Height of the camera sensor in pixels.
    ///   - orientation: Orientation applied to the captured image during normalization.
    ///   - fx: Focal length in pixels along the x-axis from the camera intrinsics.
    ///   - fy: Focal length in pixels along the y-axis from the camera intrinsics.
    /// - Returns: A `MoleSamples` struct containing the collected points, weights, and depth values, or `nil` if sampling fails due to invalid inputs.
    private func samplePixels(
        mask: (pixels: [UInt8], width: Int, height: Int),
        bounds: (minX: Int, minY: Int, maxX: Int, maxY: Int),
        depth: DepthBufferView,
        confidence: ConfidenceBufferView?,
        sensorWidth: Int,
        sensorHeight: Int,
        orientation: UIImage.Orientation,
        fx: Double,
        fy: Double
    ) -> MoleSamples {
        // Scale factor to convert mask alpha values to [0, 1] range based on renderer settings.
        let alphaScale = Double(SegmentationRendererValues.maskAlphaMax) * SegmentationRendererValues.alphaByteScale

        var points: [CGPoint] = []
        var weights: [Double] = []
        var depths: [Float] = []
        var sampledDepthPixels = Set<Int>()

        // Reserve capacity based on the bounding box size to optimize memory allocations during sampling.
        let estimatedPixelCount = max(0, (bounds.maxX - bounds.minX + 1) * (bounds.maxY - bounds.minY + 1))
        points.reserveCapacity(estimatedPixelCount)
        weights.reserveCapacity(estimatedPixelCount)
        depths.reserveCapacity(min(estimatedPixelCount, depth.width * depth.height))

        for ny in bounds.minY...bounds.maxY {
            for nx in bounds.minX...bounds.maxX {
                let pixelOffset = (ny * mask.width + nx) * LesionSizingConstants.rgbaBytesPerPixel
                let alpha = mask.pixels[pixelOffset + LesionSizingConstants.alphaChannelOffset]
                guard alpha >= LesionSizingConstants.minimumMaskAlpha else { continue }

                // Collect the normalized pixel coordinate and its corresponding mask weight.
                points.append(CGPoint(x: nx, y: ny))
                weights.append(min(1.0, Double(alpha) / alphaScale))

                // Map the normalized pixel coordinate to the original sensor space to find the corresponding depth pixel.
                let (sx, sy) = CalculatorHelper.normalizedToSensor(
                    nx: nx, ny: ny,
                    normalizedWidth: mask.width, normalizedHeight: mask.height,
                    orientation: orientation
                )

                // Scale the sensor-space coordinate to the depth map resolution. 
                // This accounts for differences in resolution 
                // and ensures we sample the correct depth value corresponding to the mask pixel.
                let dx = sx * depth.width / sensorWidth
                let dy = sy * depth.height / sensorHeight
                guard dx >= 0 && dx < depth.width && dy >= 0 && dy < depth.height else { continue }

                // Set-based deduplication of depth samples to avoid biasing the area/diameter calculations 
                // with repeated values from multiple mask pixels mapping to the same depth pixel.
                let depthIndex = dy * depth.width + dx
                guard !sampledDepthPixels.contains(depthIndex) else { continue }
                sampledDepthPixels.insert(depthIndex)

                if let value = sampleDepth(atX: dx, y: dy, depth: depth, confidence: confidence) {
                    depths.append(value)
                }
            }
        }

        return MoleSamples(
            points: points,
            weights: weights,
            depths: depths,
            fx: fx,
            fy: fy
        )
    }

    /// Reads one depth pixel, rejecting it when confidence is too low or the depth is out of range.
    /// 
    /// - Parameters:
    ///   - dx: X coordinate in the depth map.
    ///   - dy: Y coordinate in the depth map.
    ///   - depth: Locked-buffer view of the depth map.
    ///   - confidence: Optional locked-buffer view of the confidence map.
    /// - Returns: Depth in meters, or `nil` if confidence is too low or depth is out of the valid range for skin captures.
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

    /// Computes area in mm² from sampled mask weights and depth values.
    ///
    /// - Parameter samples: Gathered mole samples for the current selection.
    /// - Returns: Area in mm², or `0` when depth or weights are insufficient.
    private func computeAreaMM2(from samples: MoleSamples) -> CGFloat {
        // We use weighted pixel counting to estimate the area, where each pixel's contribution is scaled by its mask-derived weight.
        // This is done to better approximate the true lesion area, especially when the segmentation mask has soft edges or partial coverage.
        let weightedPixelCount = samples.weights.reduce(0, +)
        guard !samples.depths.isEmpty, weightedPixelCount > 0 else { return 0.0 }

        // We use the median depth value to represent the typical distance of the lesion from the camera, 
        // which helps mitigate the impact of outliers in depth measurements.
        let depthMeters = CalculatorHelper.median(of: samples.depths)
        let areaSquareMeters = weightedPixelCount * (depthMeters * depthMeters) / (samples.fx * samples.fy)
        return CGFloat(areaSquareMeters * LesionSizingConstants.squareMetersToSquareMillimeters)
    }

    /// Computes Feret-style diameter in mm from sampled points and depth values.
    ///
    /// - Parameter samples: Gathered mole samples for the current selection.
    /// - Returns: Diameter in mm, or `0` when depth/points are insufficient.
    private func computeDiameterMM(from samples: MoleSamples) -> CGFloat {

        // Diameter estimation relies on the spatial distribution of the sampled points, 
        // so we require at least 2 points to compute a non-zero diameter.
        guard !samples.depths.isEmpty,
              samples.points.count >= LesionSizingConstants.minimumDiameterPointCount else {
            return 0.0
        }

        // Similar to area, we use the median depth to represent the typical distance of the lesion,
        // which allows us to convert pixel distances into physical units while being robust to depth outliers
        let depthMeters = CalculatorHelper.median(of: samples.depths)
        let hull = CalculatorHelper.convexHull(of: samples.points)

        let maxSquaredDistance = CalculatorHelper.maxPairwiseSquaredDistance(
            in: hull,
            invFx: 1.0 / samples.fx,
            invFy: 1.0 / samples.fy
        )

        let diameterMeters = sqrt(maxSquaredDistance) * depthMeters
        return CGFloat(diameterMeters * LesionSizingConstants.metersToMillimeters)
    }

}
