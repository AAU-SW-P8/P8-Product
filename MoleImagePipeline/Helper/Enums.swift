/// Shared constants used by segmentation rendering and measurement logic.
enum SegmentationRendererValues {
    /// Opacity of the red overlay applied to detected mole areas. This is a visual design choice and does not affect area calculations, which use the raw mask.
    static let maskAlphaMax: Float = 0.5

    /// Converts an alpha fraction in [0, 1] into 8-bit channel space.
    static let alphaByteScale: Double = 255.0
}

/// Constants used by `Calculator` for mask/depth sampling and unit conversion.
enum LesionSizingConstants {
    /// Lowest non-zero alpha accepted as part of a mole mask.
    static let minimumMaskAlpha: UInt8 = 1

    /// Minimum ARKit depth confidence accepted (0=low, 1=medium, 2=high).
    static let minimumAcceptedDepthConfidence: UInt8 = 1

    /// Depths outside this range are discarded as invalid for skin captures.
    static let validDepthRangeMeters: ClosedRange<Float> = 0.05...2.0

    /// Conversion factor from meters to millimeters.
    static let metersToMillimeters: Double = 1_000.0

    /// Converts square meters to square millimeters.
    static let squareMetersToSquareMillimeters: Double = 1_000_000.0

    /// RGBA channel count in rendered mask buffers.
    static let rgbaBytesPerPixel: Int = 4

    /// Alpha channel index in RGBA buffers. Red, Green, and Blue channels are not used for area/diameter calculations, but may be used for debugging or visualization.
    static let alphaChannelOffset: Int = 3

    /// Minimum point count required to compute a non-zero diameter.
    static let minimumDiameterPointCount: Int = 2
}
