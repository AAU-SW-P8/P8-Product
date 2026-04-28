import UIKit

/// Constants used throughout the AR camera capture flow.
enum ARCameraConstants {
    
    /// Measurements and thresholds used for LiDAR and depth evaluation.
    enum Measurement {
        /// Desired subject distance in meters.
        static let targetDistance: Float = 0.30
        /// Allowed deviation around `targetDistance`, in meters.
        static let distanceTolerance: Float = 0.10
        /// Initial seeded distance before any readings are available.
        static let initialDistance: Float = 100.0
        /// Minimum depth in meters considered valid (filters out sensor noise/occlusions).
        static let minValidDepth: Float = 0.05
        /// Maximum depth in meters to visualize in the dot point cloud.
        static let maxValidDepth: Float = 2.0
        /// Multiplier to convert meters to centimeters.
        static let depthToCmMultiplier: Float = 100.0
    }
    
    /// Layout and styling constants for the camera overlay UI.
    enum UI {
        // Measurement Display
        static let measurementDisplayCornerRadius: CGFloat = 12.0
        static let measurementDisplayWidth: CGFloat = 200.0
        static let measurementDisplayHeight: CGFloat = 70.0
        static let measurementDisplayBottomPadding: CGFloat = -20.0
        static let measurementDisplayBackgroundAlpha: CGFloat = 0.9
        
        // Display Label
        static let displayLabelFontSize: CGFloat = 28.0
        static let displayLabelTopPadding: CGFloat = 8.0
        
        // Confidence Label
        static let confidenceLabelFontSize: CGFloat = 14.0
        static let confidenceLabelTopPadding: CGFloat = 4.0
        
        // Crosshair
        static let crosshairSize: CGFloat = 80.0
        static let crosshairCornerLength: CGFloat = 20.0
        static let crosshairLineWidth: CGFloat = 2.0
        
        // Capture Button
        static let captureButtonCornerRadius: CGFloat = 25.0
        static let captureButtonFontSize: CGFloat = 18.0
        static let captureButtonWidth: CGFloat = 200.0
        static let captureButtonHeight: CGFloat = 50.0
        static let captureButtonBottomPadding: CGFloat = -30.0
        
        // Cancel Button
        static let cancelButtonFontSize: CGFloat = 16.0
        static let cancelButtonTopPadding: CGFloat = 20.0
        static let cancelButtonLeadingPadding: CGFloat = 20.0
        
        // Flashlight Button
        static let flashlightButtonCornerRadius: CGFloat = 20.0
        static let flashlightButtonWidth: CGFloat = 40.0
        static let flashlightButtonHeight: CGFloat = 40.0
        static let flashlightButtonTopPadding: CGFloat = 20.0
        static let flashlightButtonTrailingPadding: CGFloat = -20.0
        static let flashlightButtonBackgroundAlpha: CGFloat = 0.5
        
        // LiDAR Dots
        static let lidarDotSize: CGFloat = 2.0
        static let lidarDotStep: Int = 4
        static let lidarDotAlpha: CGFloat = 0.6
    }

    /// Colors used in the camera overlay UI.
    enum Colors {
        static let overlayRed = UIColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1.0)
        static let overlayGreen = UIColor(red: 0.2, green: 0.8, blue: 0.3, alpha: 0.9)
    }
}
