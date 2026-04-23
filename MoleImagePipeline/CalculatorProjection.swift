import UIKit
import CoreVideo
import simd

/// Computes physical mole measurements from a segmentation mask, depth map,
/// and camera intrinsics using a pinhole projection model.
///
/// The camera intrinsics matrix (`simd_float3x3`) represents the pinhole model:
///
/// [ fx 0 cx ]
/// [ 0 fy cy ]
/// [ 0 0 1 ]
class CalculatorProjection: Calculator {

    // MARK: - Measurement

    /// Converts sampled points and depths into a physical measurement using the
    /// pinhole projection defined by the camera intrinsics.

    /// Computes area in mm² from sampled mask weights and depth values.
    private func computeAreaMM2(from samples: Calculator.MoleSamples, _ intrinsics: (fx: Double, fy: Double)) -> CGFloat {
        // We use weighted pixel counting to estimate the area, where each pixel's contribution is scaled by its mask-derived weight.
        // This is done to better approximate the true lesion area, especially when the segmentation mask has soft edges or partial coverage.
        let weightedPixelCount = samples.weights.reduce(0, +)
        guard !samples.depths.isEmpty, weightedPixelCount > 0 else { return 0.0 }

        // We use the median depth value to represent the typical distance of the lesion from the camera,
        // which helps mitigate the impact of outliers in depth measurements.
        let depthMeters = CalculatorHelper.median(of: samples.depths)
        let areaSquareMeters = weightedPixelCount * (depthMeters * depthMeters) / (intrinsics.fx * intrinsics.fy)
        return CGFloat(areaSquareMeters * LesionSizingConstants.squareMetersToSquareMillimeters)
    }

    /// Computes diameter in mm from sampled points and depth values.
    private func computeDiameterMM(from samples: Calculator.MoleSamples, _ intrinsics: (fx: Double, fy: Double)) -> CGFloat {
        // Diameter estimation relies on the spatial distribution of the sampled points,
        // so we require at least 2 points to compute a non-zero diameter.
        guard !samples.depths.isEmpty,
              samples.points.count >= LesionSizingConstants.minimumDiameterPointCount else {
            return 0.0
        }

        // Similar to area, we use the median depth to represent the typical distance of the lesion,
        // which allows us to convert pixel distances into physical units while being robust to depth outliers.
        let depthMeters = CalculatorHelper.median(of: samples.depths)
        let hull = CalculatorHelper.convexHull(of: samples.points)

        let maxSquaredDistance = CalculatorHelper.maxPairwiseSquaredDistance(
            in: hull,
            invFx: 1.0 / intrinsics.fx,
            invFy: 1.0 / intrinsics.fy
        )

        let diameterMeters = sqrt(maxSquaredDistance) * depthMeters
        return CGFloat(diameterMeters * LesionSizingConstants.metersToMillimeters)
    }
}
