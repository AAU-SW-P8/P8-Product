import UIKit

/// Utility functions used by `CalculatorLinear`.
///
/// Unlike `CalculatorHelper`, these helpers operate in raw pixel units because
/// the linear model converts pixels to millimeters through a `DistanceLookup`
/// rather than via camera intrinsics.
enum CalculatorLinearHelper {

    /// Largest squared Euclidean distance between any two input points in raw
    /// pixel units.
    ///
    /// This mirrors `CalculatorHelper.maxPairwiseSquaredDistance` but omits
    /// focal-length scaling; the caller multiplies by millimeters-per-pixel
    /// to obtain a physical distance.
    ///
    /// - Parameter points: Convex hull vertices in image pixel coordinates.
    /// - Returns: Maximum squared pixel distance.
    static func maxPairwiseSquaredPixelDistance(in points: [CGPoint]) -> Double {
        var maxSquared: Double = 0
        for i in 0..<points.count {
            for j in (i + 1)..<points.count {
                let dx = Double(points[i].x - points[j].x)
                let dy = Double(points[i].y - points[j].y)
                let sq = dx * dx + dy * dy
                if sq > maxSquared { maxSquared = sq }
            }
        }
        return maxSquared
    }
}
