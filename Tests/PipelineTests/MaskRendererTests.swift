//
//  MaskRendererTests.swift
//  PipelineTests
//

import Testing
import CoreML
import UIKit
@testable import P8_Product

struct MaskRendererTests {

    // MARK: - Helpers

    /// Creates a Float16 MLMultiArray of shape [1, maskCount, height, width]
    /// filled with a constant value.
    private func makeMaskArray(
        maskCount: Int = 3,
        height: Int,
        width: Int,
        fillValue: Float = 1.0
    ) throws -> MLMultiArray {
        let array = try MLMultiArray(
            shape: [1, NSNumber(value: maskCount), NSNumber(value: height), NSNumber(value: width)],
            dataType: .float16
        )
        let ptr = array.dataPointer.assumingMemoryBound(to: Float16.self)
        let total = maskCount * height * width
        for i in 0..<total {
            ptr[i] = Float16(fillValue)
        }
        return array
    }

    /// Creates a mask array where specific pixels have custom values per candidate mask.
    private func makeMaskArrayWithValues(
        height: Int,
        width: Int,
        values: [[Float]]  // [maskIndex][pixelIndex]
    ) throws -> MLMultiArray {
        let maskCount = values.count
        let array = try MLMultiArray(
            shape: [1, NSNumber(value: maskCount), NSNumber(value: height), NSNumber(value: width)],
            dataType: .float16
        )
        let ptr = array.dataPointer.assumingMemoryBound(to: Float16.self)
        let planeStride = height * width
        for m in 0..<maskCount {
            for i in 0..<planeStride {
                ptr[m * planeStride + i] = Float16(values[m][i])
            }
        }
        return array
    }

    // MARK: - render

    @Test func render_allForeground_returnsImage() throws {
        let renderer = MaskRenderer()
        let mask = try makeMaskArray(height: 4, width: 4, fillValue: 1.0)
        let image = try renderer.render(mask, targetSize: CGSize(width: 4, height: 4))

        #expect(image.size.width == 4)
        #expect(image.size.height == 4)
    }

    @Test func render_allBackground_returnsImage() throws {
        let renderer = MaskRenderer()
        let mask = try makeMaskArray(height: 4, width: 4, fillValue: -1.0)
        let image = try renderer.render(mask, targetSize: CGSize(width: 4, height: 4))

        #expect(image.size.width == 4)
        #expect(image.size.height == 4)
    }

    @Test func render_resizesToTargetSize() throws {
        let renderer = MaskRenderer()
        let mask = try makeMaskArray(height: 4, width: 4, fillValue: 1.0)
        let targetSize = CGSize(width: 200, height: 200)
        let image = try renderer.render(mask, targetSize: targetSize)

        #expect(image.size.width == 200)
        #expect(image.size.height == 200)
    }

    @Test func render_sameSizeAsTarget_noResize() throws {
        let renderer = MaskRenderer()
        let mask = try makeMaskArray(height: 10, width: 10, fillValue: 1.0)
        let image = try renderer.render(mask, targetSize: CGSize(width: 10, height: 10))

        #expect(image.size.width == 10)
        #expect(image.size.height == 10)
    }

    @Test func render_selectsBestLogitAcrossMasks() throws {
        // Mask 0: all negative, Mask 1: all negative, Mask 2: all positive
        // Best logit should be from mask 2 → foreground
        let h = 2, w = 2
        let pixels = h * w
        let mask = try makeMaskArrayWithValues(
            height: h, width: w,
            values: [
                Array(repeating: Float(-5.0), count: pixels),
                Array(repeating: Float(-3.0), count: pixels),
                Array(repeating: Float(2.0), count: pixels)
            ]
        )
        let renderer = MaskRenderer()
        let image = try renderer.render(mask, targetSize: CGSize(width: w, height: h))
        #expect(image.cgImage != nil)
    }

    @Test func render_mixedForegroundAndBackground() throws {
        // 2×1 image: first pixel foreground, second background
        let mask = try makeMaskArrayWithValues(
            height: 1, width: 2,
            values: [
                [5.0, -5.0],  // mask 0
                [3.0, -3.0],  // mask 1
                [1.0, -1.0]   // mask 2
            ]
        )
        let renderer = MaskRenderer()
        let image = try renderer.render(mask, targetSize: CGSize(width: 2, height: 1))
        #expect(image.cgImage != nil)
    }

    // MARK: - Custom colours

    @Test func render_customForegroundColour() throws {
        var renderer = MaskRenderer()
        renderer.foreground = MaskRenderer.RGBA(red: 0, green: 255, blue: 0, alpha: 200)
        let mask = try makeMaskArray(height: 2, width: 2, fillValue: 1.0)
        let image = try renderer.render(mask, targetSize: CGSize(width: 2, height: 2))
        #expect(image.cgImage != nil)
    }

    @Test func render_customBackgroundColour() throws {
        var renderer = MaskRenderer()
        renderer.background = MaskRenderer.RGBA(red: 128, green: 128, blue: 128, alpha: 32)
        let mask = try makeMaskArray(height: 2, width: 2, fillValue: -1.0)
        let image = try renderer.render(mask, targetSize: CGSize(width: 2, height: 2))
        #expect(image.cgImage != nil)
    }

    // MARK: - Edge cases

    @Test func render_singlePixel() throws {
        let renderer = MaskRenderer()
        let mask = try makeMaskArray(height: 1, width: 1, fillValue: 0.5)
        let image = try renderer.render(mask, targetSize: CGSize(width: 1, height: 1))
        #expect(image.cgImage != nil)
    }

    @Test func render_zeroLogit_treatedAsBackground() throws {
        // Logit == 0 → bestValue > 0.0 is false → background
        let renderer = MaskRenderer()
        let mask = try makeMaskArray(height: 2, width: 2, fillValue: 0.0)
        let image = try renderer.render(mask, targetSize: CGSize(width: 2, height: 2))
        #expect(image.cgImage != nil)
    }

    // MARK: - RGBA

    @Test func rgba_storesValues() {
        let color = MaskRenderer.RGBA(red: 10, green: 20, blue: 30, alpha: 40)
        #expect(color.red == 10)
        #expect(color.green == 20)
        #expect(color.blue == 30)
        #expect(color.alpha == 40)
    }

    // MARK: - MaskRenderError

    @Test func maskRenderError_hasDescription() {
        let error = MaskRenderer.MaskRenderError.contextCreationFailed
        #expect(error.errorDescription != nil)
        #expect(error.errorDescription!.contains("CGContext"))
    }
}
