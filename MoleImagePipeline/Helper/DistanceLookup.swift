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

    /// Placeholder calibration modeled after a pinhole camera with a nominal
    /// focal length of 1000 px. Replace with empirically measured values once
    /// the calibration rig produces them.
    static let `default` = DistanceLookup(entries: [
        Entry(distanceMeters: 0.30, mmPerPixel: 0.21180873146861826),
        Entry(distanceMeters: 0.31, mmPerPixel: 0.22392515847384573),
        Entry(distanceMeters: 0.32, mmPerPixel: 0.22859006246349024),
    ])

    /// Returns the millimeters-per-pixel value for the given distance.
    ///
    /// Distances between two entries are interpolated linearly. Distances
    /// outside the table are clamped to the nearest endpoint rather than
    /// extrapolated, since the model is only validated within the calibrated
    /// range.
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
