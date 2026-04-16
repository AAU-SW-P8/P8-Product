//
//  NormalizeOrientation.swift
//  P8-Product
//
//  Camera photos are often stored rotated which causes CoreML
//  preprocessing to see a different orientation than the renderer.
//  This file is responsible for normalizing the images to the same orientation
//

import UIKit

extension UIImage {
    /// Bakes the receiver's EXIF `imageOrientation` into its pixel buffer so
    /// that `cgImage` matches what gets rendered on screen.
    ///
    /// A `UIImage` stores raw pixels in `cgImage` plus an `imageOrientation`
    /// flag that renderers apply at draw time. Camera captures typically arrive
    /// non-`.up` (e.g. `.right` for portrait), so the underlying `cgImage` is
    /// sideways and only looks correct because `UIImage.draw` rotates it on the
    /// fly. Consumers that read `cgImage` directly — CoreML preprocessing,
    /// Vision requests — see the raw sideways pixels and disagree with the UI.
    /// Re-rendering through a graphics context physically rotates the pixels so
    /// both paths agree.
    ///
    /// - Returns: A new `.up`-oriented `UIImage` whose pixel data has been
    ///   rotated to match, or `self` if the image is already `.up`.
    ///
    /// Uses `UIGraphicsImageRenderer`, which is thread-safe and may therefore
    /// be called from a detached task without touching the main thread.
    func normalizedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }

        let format = UIGraphicsImageRendererFormat.preferred()
        format.scale = scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
