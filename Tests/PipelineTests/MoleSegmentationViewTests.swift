//
//  MoleSegmentationViewTests.swift
//  PipelineTests
//

import Testing
import SwiftUI
import CoreML
@testable import P8_Product

struct MoleSegmentationViewTests {

    // MARK: - View instantiation

    @Test func view_canBeCreated() {
        let view = MoleSegmentationTestView()
        #expect(type(of: view.body) != Never.self)
    }

    // MARK: - Integration: Coordinate + Mask pipeline

    @Test func tapAtCenter_producesValidCropRect() {
        let imageSize = CGSize(width: 1000, height: 1000)
        let viewSize = CGSize(width: 500, height: 500)
        let cropSize: CGFloat = 200

        let converter = ImageCoordinateConverter(
            imageSize: imageSize,
            viewSize: viewSize
        )

        let tapPoint = CGPoint(x: 250, y: 250) // center of view
        let pixel = converter.viewToPixel(tapPoint)
        let cropRect = converter.croppingRect(around: pixel, cropSize: cropSize)
        let pointInCrop = converter.pointInRect(pixel, relativeTo: cropRect)
        let viewBox = converter.pixelRectToView(cropRect)

        // Pixel should be center of image
        #expect(pixel.x == 500)
        #expect(pixel.y == 500)

        // Crop rect should be 200×200 centered at (500,500)
        #expect(cropRect.origin.x == 400)
        #expect(cropRect.origin.y == 400)
        #expect(cropRect.width == 200)
        #expect(cropRect.height == 200)

        // Point in crop should be at (100, 100) — center of 200×200 crop
        #expect(pointInCrop.x == 100)
        #expect(pointInCrop.y == 100)

        // View box should map back correctly
        #expect(viewBox.width == 100)  // 200/1000 * 500
        #expect(viewBox.height == 100)
    }

    @Test func tapNearEdge_cropsClampedCorrectly() {
        let imageSize = CGSize(width: 1000, height: 1000)
        let viewSize = CGSize(width: 500, height: 500)
        let cropSize: CGFloat = 200

        let converter = ImageCoordinateConverter(
            imageSize: imageSize,
            viewSize: viewSize
        )

        // Tap near bottom-right corner of the view
        let tapPoint = CGPoint(x: 490, y: 490)
        let pixel = converter.viewToPixel(tapPoint)
        let cropRect = converter.croppingRect(around: pixel, cropSize: cropSize)

        // Crop rect should be clamped so it doesn't exceed image bounds
        #expect(cropRect.maxX <= imageSize.width)
        #expect(cropRect.maxY <= imageSize.height)
        #expect(cropRect.origin.x >= 0)
        #expect(cropRect.origin.y >= 0)
        #expect(cropRect.width == 200)
        #expect(cropRect.height == 200)
    }

    @Test func tapNearTopLeft_cropsClampedCorrectly() {
        let imageSize = CGSize(width: 1000, height: 1000)
        let viewSize = CGSize(width: 500, height: 500)
        let cropSize: CGFloat = 200

        let converter = ImageCoordinateConverter(
            imageSize: imageSize,
            viewSize: viewSize
        )

        let tapPoint = CGPoint(x: 10, y: 10)
        let pixel = converter.viewToPixel(tapPoint)
        let cropRect = converter.croppingRect(around: pixel, cropSize: cropSize)

        #expect(cropRect.origin.x >= 0)
        #expect(cropRect.origin.y >= 0)
        #expect(cropRect.width == 200)
        #expect(cropRect.height == 200)
    }

    // MARK: - Aspect-fit with non-square image

    @Test func pipeline_withWideImage_coordinatesCorrect() {
        // 2000×1000 image in 400×400 view
        let converter = ImageCoordinateConverter(
            imageSize: CGSize(width: 2000, height: 1000),
            viewSize: CGSize(width: 400, height: 400)
        )

        // Displayed size: 400×200, offset: (0, 100)
        let tapPoint = CGPoint(x: 200, y: 200) // center of view
        let pixel = converter.viewToPixel(tapPoint)

        // Center of the displayed image maps to center of pixel space
        #expect(pixel.x == 1000)
        #expect(pixel.y == 500)

        let cropRect = converter.croppingRect(around: pixel, cropSize: 200)
        let viewBox = converter.pixelRectToView(cropRect)

        // viewBox should be within the displayed image region
        #expect(viewBox.origin.y >= 100) // offset.y
        #expect(viewBox.maxY <= 300)     // offset.y + displayed.height
    }

    @Test func pipeline_withTallImage_coordinatesCorrect() {
        // 1000×2000 image in 400×400 view
        let converter = ImageCoordinateConverter(
            imageSize: CGSize(width: 1000, height: 2000),
            viewSize: CGSize(width: 400, height: 400)
        )

        // Displayed size: 200×400, offset: (100, 0)
        let tapPoint = CGPoint(x: 200, y: 200)
        let pixel = converter.viewToPixel(tapPoint)

        #expect(pixel.x == 500)
        #expect(pixel.y == 1000)

        let cropRect = converter.croppingRect(around: pixel, cropSize: 200)
        let viewBox = converter.pixelRectToView(cropRect)

        // viewBox should be within the displayed image region
        #expect(viewBox.origin.x >= 100) // offset.x
        #expect(viewBox.maxX <= 300)     // offset.x + displayed.width
    }

    // MARK: - MaskRenderer integration

    @Test func maskRenderer_producesOverlayMatchingCropSize() throws {
        let cropSize = CGSize(width: 200, height: 200)
        let renderer = MaskRenderer()
        let mask = try MLMultiArray(
            shape: [1, 3, 64, 64],
            dataType: .float16
        )
        // Fill with positive values (foreground)
        let ptr = mask.dataPointer.assumingMemoryBound(to: Float16.self)
        for i in 0..<(3 * 64 * 64) {
            ptr[i] = Float16(1.0)
        }

        let overlay = try renderer.render(mask, targetSize: cropSize)
        #expect(overlay.size.width == 200)
        #expect(overlay.size.height == 200)
    }
}
