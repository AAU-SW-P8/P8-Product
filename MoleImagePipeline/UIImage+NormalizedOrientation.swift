//
//  UIImage+NormalizedOrientation.swift
//  P8-Product
//
//  Flattens EXIF orientation into the pixel data so that `cgImage` and
//  `UIImage.draw` agree on the layout. Camera photos are often stored
//  rotated (e.g. `.right` for portrait) which causes CoreML preprocessing
//  to see a different orientation than the renderer.
//

import UIKit

extension UIImage {
    /// Returns a copy whose `imageOrientation` is `.up`, with the pixel data
    /// physically rotated to match. If the image is already `.up`, returns `self`.
    func normalizedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }

        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return normalized ?? self
    }
}
