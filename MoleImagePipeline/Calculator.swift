import UIKit
import CoreVideo
import simd

class Calculator {

    /// Peak alpha the mask renderer applies to a fully-confident pixel.
    private let maskAlphaMax: Float = SegmentationRendererValues.maskAlphaMax

    /// Minimum alpha to consider a pixel as potentially part of the mole.
    /// Filters out near-zero background noise (~p=0.004).
    private let minimumAlpha: UInt8 = 1

    /// Per-pixel data extracted from the mask + depth map for a single selected mole.
    /// Produced once and consumed by both area and diameter calculations.
    private struct MoleSamples {
        /// Image-pixel coordinates (in normalized image space) of every mole pixel.
        var points: [CGPoint]
        /// Probability (0…1) per entry in `points`, recovered from the mask alpha.
        var weights: [Double]
        /// Deduplicated depth samples (meters) covering the mole's footprint, after
        /// confidence filtering and validity clamping.
        var depths: [Float]
        /// Camera focal lengths (pixels), as Doubles for downstream math.
        var fx: Double
        var fy: Double
    }

    /// Calculates the physical area of a mole in mm² using the segmentation mask,
    /// LiDAR depth map, and camera intrinsics.
    ///
    /// For each mole pixel (identified via the mask image's alpha channel) within the
    /// bounding box, the depth value is read from the depth map and combined with the
    /// camera's focal lengths to compute the physical area that pixel covers. The sum
    /// of all pixel areas gives the total mole area.
    ///
    /// - Parameters:
    ///   - segmentedImage: A tuple of (mask-only UIImage, [bounding box]). The mask image
    ///     should have alpha > 0 only on mole pixels. The array should contain exactly
    ///     one CGRect — the bounding box of the selected mole in image-pixel coordinates.
    ///   - depthMap: Float32 CVPixelBuffer from ARFrame.sceneDepth (values in meters).
    ///   - confidenceMap: UInt8 CVPixelBuffer from ARFrame.sceneDepth (0=low, 1=medium, 2=high).
    ///   - cameraIntrinsics: The 3x3 intrinsics matrix from ARFrame.camera.intrinsics.
    ///   - imageOrientation: The UIImage.Orientation applied to the captured image before
    ///     normalization. Needed to map normalized image coordinates back to sensor-aligned
    ///     depth map coordinates.
    /// - Returns: The mole area in mm², or 0 if depth data or intrinsics are unavailable.
    func calculateArea(
        from segmentedImage: (UIImage, [CGRect]),
        depthMap: CVPixelBuffer?,
        confidenceMap: CVPixelBuffer?,
        cameraIntrinsics: simd_float3x3? = nil,
        imageOrientation: UIImage.Orientation = .up
    ) -> CGFloat {
        guard let samples = gatherMoleSamples(
            from: segmentedImage,
            depthMap: depthMap,
            confidenceMap: confidenceMap,
            cameraIntrinsics: cameraIntrinsics,
            imageOrientation: imageOrientation
        ) else { return 0.0 }

        let weightedPixelCount = samples.weights.reduce(0, +)
        guard !samples.depths.isEmpty, weightedPixelCount > 0 else { return 0.0 }

        // Median depth is more robust to LiDAR noise than per-pixel depth.
        let d = median(of: samples.depths)
        let totalArea = weightedPixelCount * (d * d) / (samples.fx * samples.fy)

        // Convert m² to mm²
        return CGFloat(totalArea * 1_000_000)
    }

    /// Estimates the mole diameter in mm as the largest distance between any two
    /// mole pixels (Feret diameter) — a robust proxy for the longest visible axis.
    ///
    /// The mask pixels (alpha ≥ `minimumAlpha`) within the bounding box are reduced
    /// to their convex hull, and the maximum pairwise distance among hull vertices
    /// is converted to physical units using the median LiDAR depth and the camera's
    /// focal lengths.
    ///
    /// Parameters mirror `calculateArea`. Returns `0` when depth/intrinsics are
    /// unavailable or fewer than two mole pixels are present.
    func calculateDiameter(
        from segmentedImage: (UIImage, [CGRect]),
        depthMap: CVPixelBuffer?,
        confidenceMap: CVPixelBuffer?,
        cameraIntrinsics: simd_float3x3? = nil,
        imageOrientation: UIImage.Orientation = .up
    ) -> CGFloat {
        guard let samples = gatherMoleSamples(
            from: segmentedImage,
            depthMap: depthMap,
            confidenceMap: confidenceMap,
            cameraIntrinsics: cameraIntrinsics,
            imageOrientation: imageOrientation
        ) else { return 0.0 }

        guard !samples.depths.isEmpty, samples.points.count >= 2 else { return 0.0 }

        let d = median(of: samples.depths)
        let hull = convexHull(of: samples.points)

        // Brute-force max distance among hull vertices. Convert pixel deltas to
        // physical deltas via depth & focal length, then take Euclidean distance.
        let invFx = 1.0 / samples.fx
        let invFy = 1.0 / samples.fy
        var maxSquared: Double = 0
        for i in 0..<hull.count {
            for j in (i + 1)..<hull.count {
                let pdx = Double(hull[i].x - hull[j].x) * invFx
                let pdy = Double(hull[i].y - hull[j].y) * invFy
                let sq = pdx * pdx + pdy * pdy
                if sq > maxSquared { maxSquared = sq }
            }
        }

        let diameterMeters = sqrt(maxSquared) * d
        return CGFloat(diameterMeters * 1_000)
    }

    // MARK: - Sampling

    /// Walks the mask's bounding box once, producing the mole-pixel positions,
    /// per-pixel mask probabilities, and a deduplicated set of valid depth samples.
    /// Returns `nil` when prerequisites (depth map, intrinsics, bounding box,
    /// renderable mask, valid clamped box) are missing.
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

        let minX = max(0, Int(floor(box.minX)))
        let minY = max(0, Int(floor(box.minY)))
        let maxX = min(maskW - 1, Int(ceil(box.maxX)) - 1)
        let maxY = min(maskH - 1, Int(ceil(box.maxY)) - 1)
        guard minX <= maxX, minY <= maxY else { return nil }

        let alphaScale = Double(maskAlphaMax) * 255.0
        var points: [CGPoint] = []
        var weights: [Double] = []
        var depths: [Float] = []
        var sampledDepthPixels = Set<Int>()

        for ny in minY...maxY {
            for nx in minX...maxX {
                let pixelOffset = (ny * maskW + nx) * 4
                let alpha = maskPixels[pixelOffset + 3]
                guard alpha >= minimumAlpha else { continue }

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

                // Only sample each depth pixel once (many camera pixels
                // map to the same depth pixel at the lower resolution).
                let depthIndex = dy * depthW + dx
                guard !sampledDepthPixels.contains(depthIndex) else { continue }
                sampledDepthPixels.insert(depthIndex)

                if let confBase = confBase {
                    let confPtr = confBase.advanced(by: dy * confBytesPerRow)
                        .assumingMemoryBound(to: UInt8.self)
                    let confidence = confPtr[dx]
                    guard confidence >= 1 else { continue } // require medium or high
                }

                let depthPtr = depthBase.advanced(by: dy * depthBytesPerRow)
                    .assumingMemoryBound(to: Float32.self)
                let depth = depthPtr[dx]
                guard depth > 0.05 && depth < 2.0 else { continue }

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

    // MARK: - Helpers

    /// Returns the median of a non-empty array of Float values.
    private func median(of values: [Float]) -> Double {
        let sorted = values.sorted()
        let n = sorted.count
        if n % 2 == 1 {
            return Double(sorted[n / 2])
        } else {
            return (Double(sorted[n / 2 - 1]) + Double(sorted[n / 2])) / 2.0
        }
    }

    /// Renders a UIImage into a flat RGBA byte array for predictable pixel access.
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

        let bytesPerRow = width * 4
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

        // Flip the coordinate system so UIImage draws top-left origin
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)

        UIGraphicsPushContext(context)
        image.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        UIGraphicsPopContext()

        return (pixels, width, height)
    }

    /// Returns the sensor pixel dimensions given the normalized image dimensions
    /// and the orientation that was applied during capture.
    private func sensorDimensions(
        normalizedWidth: Int,
        normalizedHeight: Int,
        orientation: UIImage.Orientation
    ) -> (Int, Int) {
        switch orientation {
        case .right, .left, .rightMirrored, .leftMirrored:
            // Portrait: sensor is landscape, so width/height are swapped
            return (normalizedHeight, normalizedWidth)
        default:
            // Landscape or identity: sensor matches normalized
            return (normalizedWidth, normalizedHeight)
        }
    }

    /// Maps a pixel coordinate from the normalized (orientation-corrected) image
    /// back to the original sensor coordinate space.
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
            // Portrait (sensor landscape, rotated 90° CW to display)
            return (ny, normalizedWidth - 1 - nx)
        case .left:
            // Portrait upside-down (sensor landscape, rotated 90° CCW)
            return (normalizedHeight - 1 - ny, nx)
        case .down:
            // Landscape flipped (180° rotation)
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

    /// Andrew's monotone chain — O(n log n). Returns hull vertices in CCW order.
    private func convexHull(of points: [CGPoint]) -> [CGPoint] {
        guard points.count > 2 else { return points }
        let sorted = points.sorted { a, b in
            a.x != b.x ? a.x < b.x : a.y < b.y
        }

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
