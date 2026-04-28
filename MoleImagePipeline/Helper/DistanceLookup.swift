import Foundation

/// Maps a LiDAR-measured distance to a physical size per pixel using a
/// calibration table with linear interpolation.
///
/// The linear model replaces the pinhole-projection calculation: instead of
/// deriving millimeters-per-pixel from the camera intrinsics and depth on
/// every call, a calibration table captures the relationship empirically and
/// interpolates between neighboring entries at runtime.
struct DistanceLookup {

    /// One calibration sample: the physical size represented by a pixel when
    /// the subject is `distanceMeters` away from the sensor.
    struct Entry {
        /// Distance from camera in meters.
        let distanceMeters: Double
        /// Physical size of one pixel at that distance, in millimeters.
        let mmPerPixel: Double
    }

    /// Calibration entries sorted by `distanceMeters` in ascending order.
    let entries: [Entry]

    /// Creates a lookup table. Entries are copied and sorted by distance so
    /// that callers do not have to maintain the invariant themselves.
    init(entries: [Entry]) {
        self.entries = entries.sorted { $0.distanceMeters < $1.distanceMeters }
    }
    
    static let `default` = DistanceLookup(entries: [
        Entry(distanceMeters: 0.20, mmPerPixel: 0.1396),
        Entry(distanceMeters: 0.21, mmPerPixel: 0.1459),
        Entry(distanceMeters: 0.22, mmPerPixel: 0.1539),
        Entry(distanceMeters: 0.23, mmPerPixel: 0.1605),
        Entry(distanceMeters: 0.24, mmPerPixel: 0.1695),
        Entry(distanceMeters: 0.25, mmPerPixel: 0.1757),
        Entry(distanceMeters: 0.26, mmPerPixel: 0.1825),
        Entry(distanceMeters: 0.27, mmPerPixel: 0.1916),
        Entry(distanceMeters: 0.28, mmPerPixel: 0.1986),
        Entry(distanceMeters: 0.29, mmPerPixel: 0.2042),
        Entry(distanceMeters: 0.30, mmPerPixel: 0.2121),
        Entry(distanceMeters: 0.31, mmPerPixel: 0.2215),
        Entry(distanceMeters: 0.32, mmPerPixel: 0.2300),
        Entry(distanceMeters: 0.33, mmPerPixel: 0.2348),
        Entry(distanceMeters: 0.34, mmPerPixel: 0.2425),
        Entry(distanceMeters: 0.35, mmPerPixel: 0.2470),
        Entry(distanceMeters: 0.36, mmPerPixel: 0.2551),
        Entry(distanceMeters: 0.37, mmPerPixel: 0.2643),
        Entry(distanceMeters: 0.38, mmPerPixel: 0.2688),
        Entry(distanceMeters: 0.39, mmPerPixel: 0.2806),
        Entry(distanceMeters: 0.40, mmPerPixel: 0.2866)
    ])

    /// Returns the millimeters-per-pixel value for the given distance.
    ///
    /// Distances between two entries are interpolated linearly. Distances
    /// outside the table are clamped to the nearest endpoint rather than
    /// extrapolated, since the model is only validated within the calibrated
    /// range.
    /// 
    /// - Parameter distanceMeters: Distance from the camera in meters.
    /// - Returns: Estimated size of one pixel at that distance, in millimeters.
    func mmPerPixel(atDistance distanceMeters: Double) -> Double {
        guard let first = entries.first, let last = entries.last else { return 0 }
        if distanceMeters <= first.distanceMeters { return first.mmPerPixel }
        if distanceMeters >= last.distanceMeters { return last.mmPerPixel }

        for i in 1..<entries.count {
            let high = entries[i]
            if distanceMeters <= high.distanceMeters {
                let low = entries[i - 1]
                let span = high.distanceMeters - low.distanceMeters
                let t = span > 0 ? (distanceMeters - low.distanceMeters) / span : 0
                return low.mmPerPixel + t * (high.mmPerPixel - low.mmPerPixel)
            }
        }
        return last.mmPerPixel
    }
}
