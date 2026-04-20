///
/// CalculaterExtension.swift
/// P8-Product
/// 
/// Exposes `calculateArea` and `calculateDiameter` as separate methods for easier testing, while the main `calculateMetrics` method serves as the primary interface.
import UIKit
import SwiftUI
import simd

extension Calculator {

    /// Calculates mole area in mm². (Needed for tests.)
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

    /// Estimates mole diameter in mm using the largest hull-to-hull pixel distance. (Needed for tests.)
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
}
