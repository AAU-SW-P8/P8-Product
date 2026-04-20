import UIKit

/// Shared utility functions used by `Calculator` for image-space and geometry operations.
enum CalculatorHelper {

    /// Returns the median value of a non-empty Float array.
    ///
    /// - Parameter values: Float values to aggregate.
    /// - Returns: Median value as `Double`.
    static func median(of values: [Float]) -> Double {
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
    static func renderToRGBA(image: UIImage) -> (pixels: [UInt8], width: Int, height: Int)? {
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
    static func sensorDimensions(
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
    static func normalizedToSensor(
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

    /// Clamps a floating-point selection box to valid pixel bounds.
    ///
    /// - Parameters:
    ///   - box: Selection box in image coordinates.
    ///   - width: Image width in pixels.
    ///   - height: Image height in pixels.
    /// - Returns: Inclusive integer bounds, or `nil` if the clamped box is empty.
    static func clampedPixelBounds(
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

    /// Builds the convex hull of the input points using Andrew's monotone chain.
    ///
    /// - Parameter points: Input points in image pixel space.
    /// - Returns: Hull vertices in counter-clockwise order.
    static func convexHull(of points: [CGPoint]) -> [CGPoint] {
        guard points.count > 2 else { return points }
        let sorted = points.sorted { a, b in
            a.x != b.x ? a.x < b.x : a.y < b.y
        }


        /// Cross product of OA and OB vectors, i.e. z-component of their 3D cross product.
        /// - Parameters:
        ///   - o: Origin point O.
        ///   - a: Point A.
        ///   - b: Point B.
        /// - Returns: a positive value if OAB makes a left turn, negative for right turn, and zero if the points are collinear.
        func cross(_ o: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
            (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
        }

        // Build lower hull
        var lower: [CGPoint] = []
        for p in sorted {
            // Remove the last point from the hull while we turn clockwise or are collinear.
            while lower.count >= 2 && cross(lower[lower.count - 2], lower[lower.count - 1], p) <= 0 {
                lower.removeLast()
            }
            // Append the current point to the hull.
            lower.append(p)
        }

        var upper: [CGPoint] = []
        // Build upper hull in reverse order
        for p in sorted.reversed() {
            while upper.count >= 2 && cross(upper[upper.count - 2], upper[upper.count - 1], p) <= 0 {
                upper.removeLast()
            }
            upper.append(p)
        }
        // Remove the last point of each half because it's repeated at the beginning of the other half.
        lower.removeLast()
        upper.removeLast()
        return lower + upper
    }

    /// Returns the largest squared physical distance between all point pairs.
    ///
    /// - Parameters:
    ///   - points: Convex hull vertices in image pixel coordinates.
    ///   - invFx: Reciprocal x focal length.
    ///   - invFy: Reciprocal y focal length.
    /// - Returns: Maximum squared distance in normalized physical space.
    static func maxPairwiseSquaredDistance(in points: [CGPoint], invFx: Double, invFy: Double) -> Double {
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
}
