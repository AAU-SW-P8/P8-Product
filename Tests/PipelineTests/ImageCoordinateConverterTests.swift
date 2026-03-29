//
//  ImageCoordinateConverterTests.swift
//  PipelineTests
//

import Testing
import CoreGraphics
@testable import P8_Product

struct ImageCoordinateConverterTests {

    // MARK: - displayedSize

    @Test func displayedSize_widerImage_fitsToWidth() {
        // 2000×1000 image in a 400×400 view → letterboxed
        // (wide image gets empty space on top/bottom)
        let converter = ImageCoordinateConverter(
            imageSize: CGSize(width: 2000, height: 1000),
            viewSize: CGSize(width: 400, height: 400)
        )
        let displayed = converter.displayedSize
        #expect(displayed.width == 400)
        #expect(displayed.height == 200)
    }

    @Test func displayedSize_tallerImage_fitsToHeight() {
        // 1000×2000 image in a 400×400 view → pillarboxed
        // (tall image gets empty space on left/right)
        let converter = ImageCoordinateConverter(
            imageSize: CGSize(width: 1000, height: 2000),
            viewSize: CGSize(width: 400, height: 400)
        )
        let displayed = converter.displayedSize
        #expect(displayed.width == 200)
        #expect(displayed.height == 400)
    }

    @Test func displayedSize_sameAspect_fillsView() {
        let converter = ImageCoordinateConverter(
            imageSize: CGSize(width: 800, height: 400),
            viewSize: CGSize(width: 400, height: 200)
        )
        let displayed = converter.displayedSize
        #expect(displayed.width == 400)
        #expect(displayed.height == 200)
    }

    // MARK: - offset

    @Test func offset_widerImage_centeredVertically() {
        let converter = ImageCoordinateConverter(
            imageSize: CGSize(width: 2000, height: 1000),
            viewSize: CGSize(width: 400, height: 400)
        )
        let off = converter.offset
        #expect(off.x == 0)
        #expect(off.y == 100) // (400 - 200) / 2
    }

    @Test func offset_tallerImage_centeredHorizontally() {
        let converter = ImageCoordinateConverter(
            imageSize: CGSize(width: 1000, height: 2000),
            viewSize: CGSize(width: 400, height: 400)
        )
        let off = converter.offset
        #expect(off.x == 100) // (400 - 200) / 2
        #expect(off.y == 0)
    }

    // MARK: - viewToPixel

    @Test func viewToPixel_centerOfView_mapsToCenterOfImage() {
        let converter = ImageCoordinateConverter(
            imageSize: CGSize(width: 1000, height: 1000),
            viewSize: CGSize(width: 500, height: 500)
        )
        let pixel = converter.viewToPixel(CGPoint(x: 250, y: 250))
        #expect(pixel.x == 500)
        #expect(pixel.y == 500)
    }

    @Test func viewToPixel_topLeftCorner() {
        let converter = ImageCoordinateConverter(
            imageSize: CGSize(width: 1000, height: 1000),
            viewSize: CGSize(width: 500, height: 500)
        )
        let pixel = converter.viewToPixel(CGPoint(x: 0, y: 0))
        #expect(pixel.x == 0)
        #expect(pixel.y == 0)
    }

    @Test func viewToPixel_clampsNegativeToZero() {
        let converter = ImageCoordinateConverter(
            imageSize: CGSize(width: 1000, height: 500),
            viewSize: CGSize(width: 400, height: 400)
        )
        // Tap in the offset area above the displayed image
        let pixel = converter.viewToPixel(CGPoint(x: 0, y: 0))
        #expect(pixel.x >= 0)
        #expect(pixel.y >= 0)
    }

    @Test func viewToPixel_clampsToBounds() {
        let converter = ImageCoordinateConverter(
            imageSize: CGSize(width: 1000, height: 1000),
            viewSize: CGSize(width: 500, height: 500)
        )
        let pixel = converter.viewToPixel(CGPoint(x: 9999, y: 9999))
        #expect(pixel.x <= 1000)
        #expect(pixel.y <= 1000)
    }

    // MARK: - croppingRect

    @Test func croppingRect_centeredCrop() {
        let converter = ImageCoordinateConverter(
            imageSize: CGSize(width: 1000, height: 1000),
            viewSize: CGSize(width: 500, height: 500)
        )
        let rect = converter.croppingRect(around: CGPoint(x: 500, y: 500), cropSize: 200)
        #expect(rect.origin.x == 400)
        #expect(rect.origin.y == 400)
        #expect(rect.width == 200)
        #expect(rect.height == 200)
    }

    @Test func croppingRect_clampedToTopLeft() {
        let converter = ImageCoordinateConverter(
            imageSize: CGSize(width: 1000, height: 1000),
            viewSize: CGSize(width: 500, height: 500)
        )
        let rect = converter.croppingRect(around: CGPoint(x: 10, y: 10), cropSize: 200)
        #expect(rect.origin.x == 0)
        #expect(rect.origin.y == 0)
        #expect(rect.width == 200)
        #expect(rect.height == 200)
    }

    @Test func croppingRect_clampedToBottomRight() {
        let converter = ImageCoordinateConverter(
            imageSize: CGSize(width: 1000, height: 1000),
            viewSize: CGSize(width: 500, height: 500)
        )
        let rect = converter.croppingRect(around: CGPoint(x: 990, y: 990), cropSize: 200)
        #expect(rect.origin.x == 800)
        #expect(rect.origin.y == 800)
        #expect(rect.width == 200)
        #expect(rect.height == 200)
    }

    @Test func croppingRect_cropLargerThanImage_clampedToImageSize() {
        let converter = ImageCoordinateConverter(
            imageSize: CGSize(width: 100, height: 100),
            viewSize: CGSize(width: 500, height: 500)
        )
        let rect = converter.croppingRect(around: CGPoint(x: 50, y: 50), cropSize: 300)
        #expect(rect.origin.x == 0)
        #expect(rect.origin.y == 0)
        #expect(rect.width == 100)
        #expect(rect.height == 100)
    }

    // MARK: - pointInRect

    @Test func pointInRect_relativesToOrigin() {
        let converter = ImageCoordinateConverter(
            imageSize: CGSize(width: 1000, height: 1000),
            viewSize: CGSize(width: 500, height: 500)
        )
        let rect = CGRect(x: 100, y: 200, width: 200, height: 200)
        let relative = converter.pointInRect(CGPoint(x: 150, y: 250), relativeTo: rect)
        #expect(relative.x == 50)
        #expect(relative.y == 50)
    }

    // MARK: - pixelRectToView

    @Test func pixelRectToView_fullImage_coversDisplayedArea() {
        let converter = ImageCoordinateConverter(
            imageSize: CGSize(width: 1000, height: 1000),
            viewSize: CGSize(width: 500, height: 500)
        )
        let viewRect = converter.pixelRectToView(
            CGRect(x: 0, y: 0, width: 1000, height: 1000)
        )
        #expect(viewRect.origin.x == 0)
        #expect(viewRect.origin.y == 0)
        #expect(viewRect.width == 500)
        #expect(viewRect.height == 500)
    }

    @Test func pixelRectToView_halfImage() {
        let converter = ImageCoordinateConverter(
            imageSize: CGSize(width: 1000, height: 1000),
            viewSize: CGSize(width: 500, height: 500)
        )
        let viewRect = converter.pixelRectToView(
            CGRect(x: 500, y: 500, width: 500, height: 500)
        )
        #expect(viewRect.origin.x == 250)
        #expect(viewRect.origin.y == 250)
        #expect(viewRect.width == 250)
        #expect(viewRect.height == 250)
    }

    @Test func pixelRectToView_withOffset_accountsForLetterbox() {
        // Taller image → horizontal offset
        let converter = ImageCoordinateConverter(
            imageSize: CGSize(width: 1000, height: 2000),
            viewSize: CGSize(width: 400, height: 400)
        )
        let viewRect = converter.pixelRectToView(
            CGRect(x: 0, y: 0, width: 1000, height: 2000)
        )
        // displayed width = 200, offset.x = 100
        #expect(viewRect.origin.x == 100)
        #expect(viewRect.origin.y == 0)
        #expect(viewRect.width == 200)
        #expect(viewRect.height == 400)
    }

    // MARK: - Round-trip

    @Test func viewToPixel_thenPixelRectToView_roundTrips() {
        let converter = ImageCoordinateConverter(
            imageSize: CGSize(width: 2000, height: 1000),
            viewSize: CGSize(width: 400, height: 400)
        )
        let viewPoint = CGPoint(x: 200, y: 200)
        let pixel = converter.viewToPixel(viewPoint)
        let cropRect = converter.croppingRect(around: pixel, cropSize: 200)
        let viewRect = converter.pixelRectToView(cropRect)

        // The view rect should be near the tap point
        let tolerance: CGFloat = 1.0
        #expect(abs(viewRect.midX - viewPoint.x) < tolerance ||
                abs(viewRect.midY - viewPoint.y) < tolerance)
    }
}
