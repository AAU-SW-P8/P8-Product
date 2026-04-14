import CoreGraphics
import CoreVideo
import Testing
import UIKit
import simd
@testable import P8_Product

@Suite("Calculator")
struct CalculatorTests {

    @Test func calculateArea_singlePixelAtOneMeter_returnsOneSquareMillimeter() throws {
        let calculator = Calculator()
        let mask = makeMaskImage(width: 2, height: 2, alphaByPixel: [255, 0,
                                                                      0,   0])
        let depth = try makeDepthPixelBuffer(width: 2, height: 2, values: [1, 1,
                                                                             1, 1])
        let intrinsics = makeIntrinsics(fx: 1000, fy: 1000)

        let area = calculator.calculateArea(
            from: (mask, [CGRect(x: 0, y: 0, width: 2, height: 2)]),
            depthMap: depth,
            confidenceMap: nil,
            cameraIntrinsics: intrinsics,
            imageOrientation: .up
        )

        #expect(abs(Double(area) - 1.0) < 1e-6)
    }

    @Test func calculateArea_boxMaxBoundary_doesNotIncludeExtraPixel() throws {
        let calculator = Calculator()
        let mask = makeMaskImage(width: 2, height: 1, alphaByPixel: [255, 255])
        let depth = try makeDepthPixelBuffer(width: 2, height: 1, values: [1, 1])
        let intrinsics = makeIntrinsics(fx: 1000, fy: 1000)

        // A width of 1 covers only pixel x=0 in half-open image coordinates.
        let area = calculator.calculateArea(
            from: (mask, [CGRect(x: 0, y: 0, width: 1, height: 1)]),
            depthMap: depth,
            confidenceMap: nil,
            cameraIntrinsics: intrinsics,
            imageOrientation: .up
        )

        #expect(abs(Double(area) - 1.0) < 1e-6)
    }

    @Test func calculateArea_continuousWeighting_bothPixelsContribute() throws {
        let calculator = Calculator()
        let mask = makeMaskImage(width: 2, height: 1, alphaByPixel: [63, 64])
        let depth = try makeDepthPixelBuffer(width: 2, height: 1, values: [1, 1])
        let intrinsics = makeIntrinsics(fx: 1000, fy: 1000)

        let area = calculator.calculateArea(
            from: (mask, [CGRect(x: 0, y: 0, width: 2, height: 1)]),
            depthMap: depth,
            confidenceMap: nil,
            cameraIntrinsics: intrinsics,
            imageOrientation: .up
        )

        // Both pixels contribute proportionally: prob = alpha / (0.5 * 255)
        // alpha 63 → prob ≈ 0.494, alpha 64 → prob ≈ 0.502
        let prob63 = 63.0 / 127.5
        let prob64 = 64.0 / 127.5
        let expected = (prob63 + prob64) / (1000.0 * 1000.0) * 1_000_000
        #expect(abs(Double(area) - expected) < 1e-6)
    }

    @Test func calculateArea_partialAlpha_contributesProportionally() throws {
        let calculator = Calculator()
        let mask = makeMaskImage(width: 1, height: 1, alphaByPixel: [64])
        let depth = try makeDepthPixelBuffer(width: 1, height: 1, values: [1])
        let intrinsics = makeIntrinsics(fx: 1000, fy: 1000)

        let area = calculator.calculateArea(
            from: (mask, [CGRect(x: 0, y: 0, width: 1, height: 1)]),
            depthMap: depth,
            confidenceMap: nil,
            cameraIntrinsics: intrinsics,
            imageOrientation: .up
        )

        // prob = 64 / 127.5 ≈ 0.502
        let prob = 64.0 / 127.5
        let expected = prob / (1000.0 * 1000.0) * 1_000_000
        #expect(abs(Double(area) - expected) < 1e-6)
    }

    @Test func calculateArea_fullAlpha_matchesExpected() throws {
        let calculator = Calculator()
        // Alpha 127 is the max the renderer produces (0.5 * 255 ≈ 127)
        let mask = makeMaskImage(width: 2, height: 2, alphaByPixel: [127, 127,
                                                                      127, 127])
        let depth = try makeDepthPixelBuffer(width: 2, height: 2, values: [1, 1,
                                                                             1, 1])
        let intrinsics = makeIntrinsics(fx: 1000, fy: 1000)

        let area = calculator.calculateArea(
            from: (mask, [CGRect(x: 0, y: 0, width: 2, height: 2)]),
            depthMap: depth,
            confidenceMap: nil,
            cameraIntrinsics: intrinsics,
            imageOrientation: .up
        )

        // prob = 127 / 127.5 ≈ 0.996, 4 pixels
        let probPerPixel = 127.0 / 127.5
        let expected = 4.0 * probPerPixel / (1000.0 * 1000.0) * 1_000_000
        #expect(abs(Double(area) - expected) < 1e-6)
    }

    @Test func calculateArea_medianDepth_resistsOutlier() throws {
        let calculator = Calculator()
        let mask = makeMaskImage(width: 3, height: 1, alphaByPixel: [255, 255, 255])
        let depth = try makeDepthPixelBuffer(width: 3, height: 1, values: [0.20, 0.20, 0.50])
        let intrinsics = makeIntrinsics(fx: 1000, fy: 1000)

        let area = calculator.calculateArea(
            from: (mask, [CGRect(x: 0, y: 0, width: 3, height: 1)]),
            depthMap: depth,
            confidenceMap: nil,
            cameraIntrinsics: intrinsics,
            imageOrientation: .up
        )

        // 3 pixels (alpha 255 clamps to prob 1.0), median depth = 0.20
        let depthSq = 0.20 * 0.20
        let expected = 3.0 * depthSq / (1000.0 * 1000.0) * 1_000_000
        #expect(abs(Double(area) - expected) < 1e-6)
    }

    @Test func calculateArea_allDepthsInvalid_returnsZero() throws {
        let calculator = Calculator()
        let mask = makeMaskImage(width: 2, height: 1, alphaByPixel: [255, 255])
        // Depths outside valid range [0.05, 2.0]
        let depth = try makeDepthPixelBuffer(width: 2, height: 1, values: [0.01, 3.0])
        let intrinsics = makeIntrinsics(fx: 1000, fy: 1000)

        let area = calculator.calculateArea(
            from: (mask, [CGRect(x: 0, y: 0, width: 2, height: 1)]),
            depthMap: depth,
            confidenceMap: nil,
            cameraIntrinsics: intrinsics,
            imageOrientation: .up
        )

        #expect(area == 0.0)
    }

    @Test func calculateArea_lowConfidenceDepth_excludedFromDepthPool() throws {
        let calculator = Calculator()
        let mask = makeMaskImage(width: 2, height: 1, alphaByPixel: [255, 255])
        let depth = try makeDepthPixelBuffer(width: 2, height: 1, values: [0.20, 0.30])
        let confidence = try makeConfidencePixelBuffer(width: 2, height: 1, values: [0, 2])
        let intrinsics = makeIntrinsics(fx: 1000, fy: 1000)

        let area = calculator.calculateArea(
            from: (mask, [CGRect(x: 0, y: 0, width: 2, height: 1)]),
            depthMap: depth,
            confidenceMap: confidence,
            cameraIntrinsics: intrinsics,
            imageOrientation: .up
        )

        // Both pixels count for area (prob clamped to 1.0 each),
        // but only the second depth (0.30, high confidence) enters the median.
        let depthSq = 0.30 * 0.30
        let expected = 2.0 * depthSq / (1000.0 * 1000.0) * 1_000_000
        #expect(abs(Double(area) - expected) < 1e-6)
    }

    // MARK: - Test helpers

    private func makeIntrinsics(fx: Float, fy: Float) -> simd_float3x3 {
        simd_float3x3(
            SIMD3<Float>(fx, 0, 0),
            SIMD3<Float>(0, fy, 0),
            SIMD3<Float>(0, 0, 1)
        )
    }

    private func makeMaskImage(width: Int, height: Int, alphaByPixel: [UInt8]) -> UIImage {
        precondition(alphaByPixel.count == width * height)

        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        for i in 0..<alphaByPixel.count {
            let a = alphaByPixel[i]
            let o = i * 4
            // Premultiplied white to match the image bitmap format.
            rgba[o] = a
            rgba[o + 1] = a
            rgba[o + 2] = a
            rgba[o + 3] = a
        }

        let data = Data(rgba)
        let provider = CGDataProvider(data: data as CFData)!
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        let cgImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )!

        return UIImage(cgImage: cgImage, scale: 1.0, orientation: .up)
    }

    private func makeConfidencePixelBuffer(width: Int, height: Int, values: [UInt8]) throws -> CVPixelBuffer {
        precondition(values.count == width * height)

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_OneComponent8,
            nil,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let pixelBuffer else {
            throw NSError(domain: "CalculatorTests", code: Int(status))
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            throw NSError(domain: "CalculatorTests", code: -1)
        }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let ptr = base.assumingMemoryBound(to: UInt8.self)
        for y in 0..<height {
            for x in 0..<width {
                ptr[y * bytesPerRow + x] = values[y * width + x]
            }
        }

        return pixelBuffer
    }

    private func makeDepthPixelBuffer(width: Int, height: Int, values: [Float32]) throws -> CVPixelBuffer {
        precondition(values.count == width * height)

        let attrs: CFDictionary = [
            kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary
        ] as CFDictionary

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_DepthFloat32,
            attrs,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let pixelBuffer else {
            throw NSError(domain: "CalculatorTests", code: Int(status))
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            throw NSError(domain: "CalculatorTests", code: -1)
        }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let floatsPerRow = bytesPerRow / MemoryLayout<Float32>.stride

        let ptr = base.assumingMemoryBound(to: Float32.self)
        for y in 0..<height {
            for x in 0..<width {
                ptr[y * floatsPerRow + x] = values[y * width + x]
            }
        }

        return pixelBuffer
    }
}
