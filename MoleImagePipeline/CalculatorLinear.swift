import CoreVideo
import UIKit
import simd

/// Computes physical mole measurements using a linear distance→mm/pixel model.
///
/// Where the projection strategy requires camera intrinsics to convert pixel
/// counts into physical units, this subclass replaces that step with a
/// `DistanceLookup`: the median depth of the lesion samples is mapped through
/// the calibration table to obtain a single millimeters-per-pixel factor,
/// which is then applied to both area and diameter.
class CalculatorLinear: Calculator {

  // MARK: - Measurement

  override func measure(from samples: Calculator.MoleSamples, cameraIntrinsics: simd_float3x3?)
    -> Calculator.MoleMeasurement {
    let medianDepth = CalculatorHelper.median(of: samples.depths)
    let mmPerPixel = distanceLookup.mmPerPixel(atDistance: medianDepth)
    return Calculator.MoleMeasurement(
      areaMM2: computeAreaMM2(from: samples, mmPerPixel),
      diameterMM: computeDiameterMM(from: samples, mmPerPixel)
    )
  }

  /// Computes area in mm² using the linear mm-per-pixel factor.
  private func computeAreaMM2(from samples: Calculator.MoleSamples, _ mmPerPixel: Double) -> CGFloat {
    let weightedPixelCount = samples.weights.reduce(0, +)
    guard weightedPixelCount > 0 else { return 0.0 }

    // Each pixel represents a square of side `mmPerPixel` millimeters.
    let areaSquareMM = weightedPixelCount * mmPerPixel * mmPerPixel
    return CGFloat(areaSquareMM)
  }

  /// Computes Feret-style diameter in mm using the linear mm-per-pixel factor.
  private func computeDiameterMM(from samples: Calculator.MoleSamples, _ mmPerPixel: Double)
    -> CGFloat {
    guard samples.points.count >= LesionSizingConstants.minimumDiameterPointCount else {
      return 0.0
    }
    let hull = CalculatorHelper.convexHull(of: samples.points)
    let maxSquaredPixels = CalculatorHelper.maxPairwiseSquaredDistance(in: hull)

    let diameterMM = sqrt(maxSquaredPixels) * mmPerPixel
    return CGFloat(diameterMM)
  }
}
