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

        guard let renderedMask = renderToRGBA(image: segmentedImage.0) else { return nil }
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

        let (sensorW, sensorH) = sensorDimensions(
            normalizedWidth: maskW,
            normalizedHeight: maskH,
            orientation: imageOrientation
        )
        guard sensorW > 0 && sensorH > 0 else { return nil }

        guard let bounds = clampedPixelBounds(for: box, width: maskW, height: maskH) else {
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

                let (sx, sy) = normalizedToSensor(
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

        let depthMeters = median(of: samples.depths)
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

        let depthMeters = median(of: samples.depths)
        let hull = convexHull(of: samples.points)

        let maxSquaredDistance = maxPairwiseSquaredDistance(
            in: hull,
            invFx: 1.0 / samples.fx,
            invFy: 1.0 / samples.fy
        )

        let diameterMeters = sqrt(maxSquaredDistance) * depthMeters
        return CGFloat(diameterMeters * CalculatorValues.metersToMillimeters)
    }

    /// Returns the largest squared physical distance between all point pairs.
    ///
    /// - Parameters:
    ///   - points: Convex hull vertices in image pixel coordinates.
    ///   - invFx: Reciprocal x focal length.
    ///   - invFy: Reciprocal y focal length.
    /// - Returns: Maximum squared distance in normalized physical space.
    private func maxPairwiseSquaredDistance(in points: [CGPoint], invFx: Double, invFy: Double) -> Double {
        var maxSquared: Double = 0
        for i in 0..<points.count {
            for j in (i + 1)..<points.count {
                let pdx = Double(points[i].x - points[j].x) * invFx
                let pdy = Double(points[i].y - points[j].y) * invFy
                let sq = pdx * pdx + pdy * pdy
                if sq > maxSquared { maxSquared = sq }
            }
        }
        return maxSquared
    }

    /// Clamps a floating-point selection box to valid pixel bounds.
    ///
    /// - Parameters:
    ///   - box: Selection box in image coordinates.
    ///   - width: Image width in pixels.
    ///   - height: Image height in pixels.
    /// - Returns: Inclusive integer bounds, or `nil` if the clamped box is empty.
    private func clampedPixelBounds(
        for box: CGRect,
        width: Int,
        height: Int
    ) -> (minX: Int, minY: Int, maxX: Int, maxY: Int)? {
        let minX = max(0, Int(floor(box.minX)))
        let minY = max(0, Int(floor(box.minY)))
        let maxX = min(width - 1, Int(ceil(box.maxX)) - 1)
        let maxY = min(height - 1, Int(ceil(box.maxY)) - 1)
        guard minX <= maxX, minY <= maxY else { return nil }
        return (minX, minY, maxX, maxY)
    }

    // MARK: - Helpers

    /// Returns the median value of a non-empty Float array.
    ///
    /// - Parameter values: Float values to aggregate.
    /// - Returns: Median value as `Double`.
    private func median(of values: [Float]) -> Double {
        let sorted = values.sorted()
        let n = sorted.count
        if n % 2 == 1 {
            return Double(sorted[n / 2])
        } else {
            return (Double(sorted[n / 2 - 1]) + Double(sorted[n / 2])) / 2.0
        }
    }

    /// Renders an image into a flat RGBA buffer for deterministic pixel access.
    ///
    /// - Parameter image: Source image.
    /// - Returns: Pixel bytes with width/height metadata, or `nil` if rendering fails.
    private func renderToRGBA(image: UIImage) -> (pixels: [UInt8], width: Int, height: Int)? {
        let width: Int
        let height: Int
        if let cgImage = image.cgImage {
            width = cgImage.width
            height = cgImage.height
        } else {
            width = Int((image.size.width * image.scale).rounded())
            height = Int((image.size.height * image.scale).rounded())
        }
        guard width > 0 && height > 0 else { return nil }

        let bytesPerRow = width * CalculatorValues.rgbaBytesPerPixel
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return nil }

        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)

        UIGraphicsPushContext(context)
        image.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        UIGraphicsPopContext()

        return (pixels, width, height)
    }

    /// Returns the sensor pixel dimensions given the normalized image dimensions
    /// and the orientation that was applied during capture.
    ///
    /// - Parameters:
    ///   - normalizedWidth: Width of the normalized image in pixels.
    ///   - normalizedHeight: Height of the normalized image in pixels.
    ///   - orientation: Orientation applied to the captured image.
    /// - Returns: Sensor-aligned width and height in pixels.
    private func sensorDimensions(
        normalizedWidth: Int,
        normalizedHeight: Int,
        orientation: UIImage.Orientation
    ) -> (Int, Int) {
        switch orientation {
        case .right, .left, .rightMirrored, .leftMirrored:
            return (normalizedHeight, normalizedWidth)
        default:
            return (normalizedWidth, normalizedHeight)
        }
    }

    /// Maps a pixel coordinate from the normalized (orientation-corrected) image
    /// back to the original sensor coordinate space.
    ///
    /// - Parameters:
    ///   - nx: X coordinate in normalized image space.
    ///   - ny: Y coordinate in normalized image space.
    ///   - normalizedWidth: Width of normalized image in pixels.
    ///   - normalizedHeight: Height of normalized image in pixels.
    ///   - orientation: Orientation applied to the captured image.
    /// - Returns: Sensor-space `(x, y)` coordinate.
    private func normalizedToSensor(
        nx: Int,
        ny: Int,
        normalizedWidth: Int,
        normalizedHeight: Int,
        orientation: UIImage.Orientation
    ) -> (Int, Int) {
        switch orientation {
        case .up:
            return (nx, ny)
        case .right:
            return (ny, normalizedWidth - 1 - nx)
        case .left:
            return (normalizedHeight - 1 - ny, nx)
        case .down:
            return (normalizedWidth - 1 - nx, normalizedHeight - 1 - ny)
        case .upMirrored:
            return (normalizedWidth - 1 - nx, ny)
        case .downMirrored:
            return (nx, normalizedHeight - 1 - ny)
        case .leftMirrored:
            return (ny, nx)
        case .rightMirrored:
            return (normalizedHeight - 1 - ny, normalizedWidth - 1 - nx)
        @unknown default:
            return (nx, ny)
        }
    }

    /// Builds the convex hull of the input points using Andrew's monotone chain.
    ///
    /// - Parameter points: Input points in image pixel space.
    /// - Returns: Hull vertices in counter-clockwise order.
    private func convexHull(of points: [CGPoint]) -> [CGPoint] {
        guard points.count > 2 else { return points }
        let sorted = points.sorted { a, b in
            a.x != b.x ? a.x < b.x : a.y < b.y
        }

        /// Signed z-component of OA x OB used for turn direction tests.
        func cross(_ o: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
            (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
        }

        var lower: [CGPoint] = []
        for p in sorted {
            while lower.count >= 2 && cross(lower[lower.count - 2], lower[lower.count - 1], p) <= 0 {
                lower.removeLast()
            }
            lower.append(p)
        }

        var upper: [CGPoint] = []
        for p in sorted.reversed() {
            while upper.count >= 2 && cross(upper[upper.count - 2], upper[upper.count - 1], p) <= 0 {
                upper.removeLast()
            }
            upper.append(p)
        }

        lower.removeLast()
        upper.removeLast()
        return lower + upper
    }
}
