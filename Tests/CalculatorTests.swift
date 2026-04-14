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

    @Test func calculateArea_alphaThreshold_borderlineValues_behaveAsExpected() throws {
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

        // Threshold is 64: alpha 63 excluded, alpha 64 included.
        #expect(abs(Double(area) - 1.0) < 1e-6)
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
