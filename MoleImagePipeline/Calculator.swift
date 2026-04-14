import UIKit
import CoreVideo
import simd

class Calculator {

    /// Alpha threshold used to treat a mask pixel as part of the mole.
    ///
    /// The mask renderer writes alpha from sigmoid(logit) with a 0.5 max alpha,
    /// so alpha ~= 64 corresponds to logit ~= 0 (probability ~= 0.5).
    private let measurementAlphaThreshold: UInt8 = 64

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
        guard let depthMap = depthMap,
              let intrinsics = cameraIntrinsics,
              let box = segmentedImage.1.first else {
            return 0.0
        }

        let maskImage = segmentedImage.0
        let fx = intrinsics[0][0]
        let fy = intrinsics[1][1]

        guard fx > 0 && fy > 0 else { return 0.0 }

        // Render the mask UIImage into a known RGBA bitmap for reliable pixel access
        guard let renderedMask = renderToRGBA(image: maskImage) else { return 0.0 }
        let maskPixels = renderedMask.pixels
        let maskW = renderedMask.width
        let maskH = renderedMask.height

        // Lock depth map
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
        guard let depthBase = CVPixelBufferGetBaseAddress(depthMap) else { return 0.0 }
        let depthW = CVPixelBufferGetWidth(depthMap)
        let depthH = CVPixelBufferGetHeight(depthMap)
        let depthBytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)

        // Lock confidence map if available
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

        // Compute sensor dimensions from orientation + normalized image size
        let (sensorW, sensorH) = sensorDimensions(
            normalizedWidth: maskW,
            normalizedHeight: maskH,
            orientation: imageOrientation
        )
        guard sensorW > 0 && sensorH > 0 else { return 0.0 }

        // Clamp the bounding box to image bounds
        let minX = max(0, Int(floor(box.minX)))
        let minY = max(0, Int(floor(box.minY)))
        let maxX = min(maskW - 1, Int(ceil(box.maxX)) - 1)
        let maxY = min(maskH - 1, Int(ceil(box.maxY)) - 1)

        guard minX <= maxX, minY <= maxY else { return 0.0 }

        var totalArea: Double = 0.0

        for ny in minY...maxY {
            for nx in minX...maxX {
                // Check alpha in the mask image (offset 3 = alpha in RGBA)
                let pixelOffset = (ny * maskW + nx) * 4
                let alpha = maskPixels[pixelOffset + 3]
                guard alpha >= measurementAlphaThreshold else { continue }

                // Map normalized image coords to sensor coords
                let (sx, sy) = normalizedToSensor(
                    nx: nx, ny: ny,
                    normalizedWidth: maskW, normalizedHeight: maskH,
                    orientation: imageOrientation
                )

                // Map sensor coords to depth map coords
                let dx = sx * depthW / sensorW
                let dy = sy * depthH / sensorH
                guard dx >= 0 && dx < depthW && dy >= 0 && dy < depthH else { continue }

                // Check confidence (skip low confidence pixels)
                if let confBase = confBase {
                    let confPtr = confBase.advanced(by: dy * confBytesPerRow)
                        .assumingMemoryBound(to: UInt8.self)
                    let confidence = confPtr[dx]
                    guard confidence >= 1 else { continue } // require medium or high
                }

                // Read depth value
                let depthPtr = depthBase.advanced(by: dy * depthBytesPerRow)
                    .assumingMemoryBound(to: Float32.self)
                let depth = depthPtr[dx]
                guard depth > 0.05 && depth < 2.0 else { continue }

                // Physical area of this pixel at the measured depth
                // area = d² / (fx * fy) in meters²
                let d = Double(depth)
                totalArea += (d * d) / (Double(fx) * Double(fy))
            }
        }

        // Convert m² to mm²
        return CGFloat(totalArea * 1_000_000)
    }

    // MARK: - Helpers

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
        case .right:
            // Portrait (sensor landscape, rotated 90° CW to display)
            // Reverse: sx = ny, sy = normW - 1 - nx
            return (ny, normalizedWidth - 1 - nx)
        case .left:
            // Portrait upside-down (sensor landscape, rotated 90° CCW)
            // Reverse: sx = normH - 1 - ny, sy = nx
            return (normalizedHeight - 1 - ny, nx)
        case .down:
            // Landscape flipped (180° rotation)
            return (normalizedWidth - 1 - nx, normalizedHeight - 1 - ny)
        default:
            // .up or mirrored variants: identity mapping
            return (nx, ny)
        }
    }
}
