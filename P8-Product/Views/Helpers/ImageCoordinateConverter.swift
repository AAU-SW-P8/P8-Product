//
//  ImageCoordinateConverter.swift
//  P8-Product
//
//  Created by Adomas Ciplys on 3/27/26.
//

import Foundation
import CoreGraphics

/// Converts between view coordinates and image-pixel coordinates for aspect-fit images.
///
/// When an image is displayed with `.scaledToFit()`, SwiftUI centers it within its frame
/// and scales it proportionally. This helper calculates the actual displayed size and offset,
/// enabling conversion between tap locations in the view and pixel coordinates in the original image.
struct ImageCoordinateConverter {
    /// The original image size in pixels
    let imageSize: CGSize
    
    /// The size of the view containing the image
    let viewSize: CGSize
    
    // MARK: - Computed Properties
    
    /// The actual size the image occupies after aspect-fit scaling
    var displayedSize: CGSize {
        let imageAspect = imageSize.width / imageSize.height
        let viewAspect = viewSize.width / viewSize.height
        
        if imageAspect > viewAspect {
            // Image is wider than the view — fits to width, pillarboxed vertically
            return CGSize(width: viewSize.width, height: viewSize.width / imageAspect)
        } else {
            // Image is taller than the view — fits to height, letterboxed horizontally
            return CGSize(width: viewSize.height * imageAspect, height: viewSize.height)
        }
    }
    
    /// The offset from the view's origin to the displayed image's origin (accounts for centering)
    var offset: CGPoint {
        let displayed = displayedSize
        return CGPoint(
            x: (viewSize.width - displayed.width) / 2,
            y: (viewSize.height - displayed.height) / 2
        )
    }
    
    // MARK: - Conversion Methods
    
    /// Converts a point from view coordinates to image-pixel coordinates
    /// - Parameter viewPoint: A point in the view's coordinate space
    /// - Returns: The corresponding point in image-pixel coordinates, clamped to image bounds
    func viewToPixel(_ viewPoint: CGPoint) -> CGPoint {
        let displayed = displayedSize
        let off = offset
        
        let x = (viewPoint.x - off.x) / displayed.width * imageSize.width
        let y = (viewPoint.y - off.y) / displayed.height * imageSize.height
        
        return CGPoint(
            x: max(0, min(imageSize.width, x)),
            y: max(0, min(imageSize.height, y))
        )
    }
    
    /// Builds a square crop rect in pixel space, clamped to the image bounds.
    /// - Parameters:
    ///   - center: The center of the crop in image-pixel coordinates.
    ///   - cropSize: The side length of the square crop.
    /// - Returns: A clamped `CGRect` in image-pixel coordinates.
    func croppingRect(around center: CGPoint, cropSize: CGFloat) -> CGRect {
        let halfCrop = cropSize / 2
        let clampedSize = CGSize(
            width:  min(cropSize, imageSize.width),
            height: min(cropSize, imageSize.height)
        )
        return CGRect(
            x: max(0, min(imageSize.width  - clampedSize.width,  center.x - halfCrop)),
            y: max(0, min(imageSize.height - clampedSize.height, center.y - halfCrop)),
            width:  clampedSize.width,
            height: clampedSize.height
        )
    }

    /// Returns a point expressed relative to a rectangle's origin.
    /// - Parameters:
    ///   - point: A point in image-pixel coordinates.
    ///   - rect: The rectangle whose origin becomes the new origin.
    /// - Returns: The point offset by the rectangle's origin.
    func pointInRect(_ point: CGPoint, relativeTo rect: CGRect) -> CGPoint {
        CGPoint(x: point.x - rect.origin.x, y: point.y - rect.origin.y)
    }

    /// Converts a rectangle from image-pixel coordinates to view coordinates
    /// - Parameter pixelRect: A rectangle in the image's pixel coordinate space
    /// - Returns: The corresponding rectangle in the view's coordinate space
    func pixelRectToView(_ pixelRect: CGRect) -> CGRect {
        let displayed = displayedSize
        let off = offset
        
        return CGRect(
            x: off.x + (pixelRect.origin.x / imageSize.width) * displayed.width,
            y: off.y + (pixelRect.origin.y / imageSize.height) * displayed.height,
            width: (pixelRect.width / imageSize.width) * displayed.width,
            height: (pixelRect.height / imageSize.height) * displayed.height
        )
    }
}
