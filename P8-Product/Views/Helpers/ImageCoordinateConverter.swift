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
