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
                                                                      0, 0])
        let depth = try makeDepthPixelBuffer(width: 2, height: 2, values: [1, 1,
                                                                             1, 1])
        let intrinsics = makeIntrinsics(fx: 1000, fy: 1000)

        let area = calculator.calculateMetrics(
            from: (mask, [CGRect(x: 0, y: 0, width: 2, height: 2)]),
            depthMap: depth,
            confidenceMap: nil,
            cameraIntrinsics: intrinsics,
            imageOrientation: .up,
            model: .projection
        ).areaMM2

        #expect(abs(Double(area) - 1.0) < 1e-6)
    }

    @Test func calculateArea_boxMaxBoundary_doesNotIncludeExtraPixel() throws {
        let calculator = Calculator()
        let mask = makeMaskImage(width: 2, height: 1, alphaByPixel: [255, 255])
        let depth = try makeDepthPixelBuffer(width: 2, height: 1, values: [1, 1])
        let intrinsics = makeIntrinsics(fx: 1000, fy: 1000)

        // A width of 1 covers only pixel x=0 in half-open image coordinates.
        let area = calculator.calculateMetrics(
            from: (mask, [CGRect(x: 0, y: 0, width: 1, height: 1)]),
            depthMap: depth,
            confidenceMap: nil,
            cameraIntrinsics: intrinsics,
            imageOrientation: .up,
            model: .projection
        ).areaMM2

        #expect(abs(Double(area) - 1.0) < 1e-6)
    }

    @Test func calculateArea_continuousWeighting_bothPixelsContribute() throws {
        let calculator = Calculator()
        let mask = makeMaskImage(width: 2, height: 1, alphaByPixel: [63, 64])
        let depth = try makeDepthPixelBuffer(width: 2, height: 1, values: [1, 1])
        let intrinsics = makeIntrinsics(fx: 1000, fy: 1000)

        let area = calculator.calculateMetrics(
            from: (mask, [CGRect(x: 0, y: 0, width: 2, height: 1)]),
            depthMap: depth,
            confidenceMap: nil,
            cameraIntrinsics: intrinsics,
            imageOrientation: .up,
            model: .projection
        ).areaMM2

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

        let area = calculator.calculateMetrics(
            from: (mask, [CGRect(x: 0, y: 0, width: 1, height: 1)]),
            depthMap: depth,
            confidenceMap: nil,
            cameraIntrinsics: intrinsics,
            imageOrientation: .up,
            model: .projection
        ).areaMM2

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

        let area = calculator.calculateMetrics(
            from: (mask, [CGRect(x: 0, y: 0, width: 2, height: 2)]),
            depthMap: depth,
            confidenceMap: nil,
            cameraIntrinsics: intrinsics,
            imageOrientation: .up,
            model: .projection
        ).areaMM2

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

        let area = calculator.calculateMetrics(
            from: (mask, [CGRect(x: 0, y: 0, width: 3, height: 1)]),
            depthMap: depth,
            confidenceMap: nil,
            cameraIntrinsics: intrinsics,
            imageOrientation: .up,
            model: .projection
        ).areaMM2

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

        let area = calculator.calculateMetrics(
            from: (mask, [CGRect(x: 0, y: 0, width: 2, height: 1)]),
            depthMap: depth,
            confidenceMap: nil,
            cameraIntrinsics: intrinsics,
            imageOrientation: .up,
            model: .projection
        ).areaMM2

        #expect(area == 0.0)
    }

    @Test func calculateArea_lowConfidenceDepth_excludedFromDepthPool() throws {
        let calculator = Calculator()
        let mask = makeMaskImage(width: 2, height: 1, alphaByPixel: [255, 255])
        let depth = try makeDepthPixelBuffer(width: 2, height: 1, values: [0.20, 0.30])
        let confidence = try makeConfidencePixelBuffer(width: 2, height: 1, values: [0, 2])
        let intrinsics = makeIntrinsics(fx: 1000, fy: 1000)

        let area = calculator.calculateMetrics(
            from: (mask, [CGRect(x: 0, y: 0, width: 2, height: 1)]),
            depthMap: depth,
            confidenceMap: confidence,
            cameraIntrinsics: intrinsics,
            imageOrientation: .up,
            model: .projection
        ).areaMM2

        // Both pixels count for area (prob clamped to 1.0 each),
        // but only the second depth (0.30, high confidence) enters the median.
        let depthSq = 0.30 * 0.30
        let expected = 2.0 * depthSq / (1000.0 * 1000.0) * 1_000_000
        #expect(abs(Double(area) - expected) < 1e-6)
    }

    // MARK: - Guard path tests

    @Test func calculateArea_nilDepthMap_returnsZero() throws {
        let calculator = Calculator()
        let mask = makeMaskImage(width: 1, height: 1, alphaByPixel: [255])
        let intrinsics = makeIntrinsics(fx: 1000, fy: 1000)

        let area = calculator.calculateMetrics(
            from: (mask, [CGRect(x: 0, y: 0, width: 1, height: 1)]),
            depthMap: nil,
            confidenceMap: nil,
            cameraIntrinsics: intrinsics,
            imageOrientation: .up,
            model: .projection
        ).areaMM2

        #expect(area == 0.0)
    }

    @Test func calculateArea_nilIntrinsics_returnsZero() throws {
        let calculator = Calculator()
        let mask = makeMaskImage(width: 1, height: 1, alphaByPixel: [255])
        let depth = try makeDepthPixelBuffer(width: 1, height: 1, values: [1])

        let area = calculator.calculateMetrics(
            from: (mask, [CGRect(x: 0, y: 0, width: 1, height: 1)]),
            depthMap: depth,
            confidenceMap: nil,
            cameraIntrinsics: nil,
            imageOrientation: .up,
            model: .projection
        ).areaMM2

        #expect(area == 0.0)
    }

    @Test func calculateArea_emptyBoundingBoxes_returnsZero() throws {
        let calculator = Calculator()
        let mask = makeMaskImage(width: 1, height: 1, alphaByPixel: [255])
        let depth = try makeDepthPixelBuffer(width: 1, height: 1, values: [1])
        let intrinsics = makeIntrinsics(fx: 1000, fy: 1000)

        let area = calculator.calculateMetrics(
            from: (mask, []),
            depthMap: depth,
            confidenceMap: nil,
            cameraIntrinsics: intrinsics,
            imageOrientation: .up,
            model: .projection
        ).areaMM2

        #expect(area == 0.0)
    }

    @Test func calculateArea_zeroFocalLength_returnsZero() throws {
        let calculator = Calculator()
        let mask = makeMaskImage(width: 1, height: 1, alphaByPixel: [255])
        let depth = try makeDepthPixelBuffer(width: 1, height: 1, values: [1])
        let intrinsics = makeIntrinsics(fx: 0, fy: 1000)

        let area = calculator.calculateMetrics(
            from: (mask, [CGRect(x: 0, y: 0, width: 1, height: 1)]),
            depthMap: depth,
            confidenceMap: nil,
            cameraIntrinsics: intrinsics,
            imageOrientation: .up,
            model: .projection
        ).areaMM2

        #expect(area == 0.0)
    }

    // MARK: - Diameter tests

    @Test func calculateDiameter_twoAdjacentPixels_returnsOneMillimeter() throws {
        let calculator = Calculator()
        let mask = makeMaskImage(width: 2, height: 1, alphaByPixel: [255, 255])
        let depth = try makeDepthPixelBuffer(width: 2, height: 1, values: [1, 1])
        let intrinsics = makeIntrinsics(fx: 1000, fy: 1000)

        let diameter = calculator.calculateMetrics(
            from: (mask, [CGRect(x: 0, y: 0, width: 2, height: 1)]),
            depthMap: depth,
            confidenceMap: nil,
            cameraIntrinsics: intrinsics,
            imageOrientation: .up,
            model: .projection
        ).diameterMM

        // pdx = 1 / fx = 1e-3, depth = 1m → diameter = 1mm
        #expect(abs(Double(diameter) - 1.0) < 1e-6)
    }

    @Test func calculateDiameter_singlePixel_returnsZero() throws {
        let calculator = Calculator()
        let mask = makeMaskImage(width: 1, height: 1, alphaByPixel: [255])
        let depth = try makeDepthPixelBuffer(width: 1, height: 1, values: [1])
        let intrinsics = makeIntrinsics(fx: 1000, fy: 1000)

        let diameter = calculator.calculateMetrics(
            from: (mask, [CGRect(x: 0, y: 0, width: 1, height: 1)]),
            depthMap: depth,
            confidenceMap: nil,
            cameraIntrinsics: intrinsics,
            imageOrientation: .up,
            model: .projection
        ).diameterMM

        // Only one masked point → below minimumDiameterPointCount.
        #expect(diameter == 0.0)
    }

    @Test func calculateDiameter_allDepthsInvalid_returnsZero() throws {
        let calculator = Calculator()
        let mask = makeMaskImage(width: 2, height: 1, alphaByPixel: [255, 255])
        let depth = try makeDepthPixelBuffer(width: 2, height: 1, values: [0.01, 3.0])
        let intrinsics = makeIntrinsics(fx: 1000, fy: 1000)

        let diameter = calculator.calculateMetrics(
            from: (mask, [CGRect(x: 0, y: 0, width: 2, height: 1)]),
            depthMap: depth,
            confidenceMap: nil,
            cameraIntrinsics: intrinsics,
            imageOrientation: .up,
            model: .projection
        ).diameterMM

        #expect(diameter == 0.0)
    }

    @Test func calculateDiameter_nilDepthMap_returnsZero() throws {
        let calculator = Calculator()
        let mask = makeMaskImage(width: 2, height: 1, alphaByPixel: [255, 255])
        let intrinsics = makeIntrinsics(fx: 1000, fy: 1000)

        let diameter = calculator.calculateMetrics(
            from: (mask, [CGRect(x: 0, y: 0, width: 2, height: 1)]),
            depthMap: nil,
            confidenceMap: nil,
            cameraIntrinsics: intrinsics,
            imageOrientation: .up,
            model: .projection
        ).diameterMM

        #expect(diameter == 0.0)
    }

    // MARK: - Combined metrics tests

    @Test func calculateMetrics_returnsBothAreaAndDiameter() throws {
        let calculator = Calculator()
        let mask = makeMaskImage(width: 2, height: 1, alphaByPixel: [255, 255])
        let depth = try makeDepthPixelBuffer(width: 2, height: 1, values: [1, 1])
        let intrinsics = makeIntrinsics(fx: 1000, fy: 1000)

        let metrics = calculator.calculateMetrics(
            from: (mask, [CGRect(x: 0, y: 0, width: 2, height: 1)]),
            depthMap: depth,
            confidenceMap: nil,
            cameraIntrinsics: intrinsics,
            imageOrientation: .up,
            model: .projection
        )

        // 2 pixels at depth 1m with fx=fy=1000 → 2 mm², 1 mm across.
        #expect(abs(Double(metrics.areaMM2) - 2.0) < 1e-6)
        #expect(abs(Double(metrics.diameterMM) - 1.0) < 1e-6)
    }

    @Test func calculateMetrics_nilDepthMap_returnsZeros() throws {
        let calculator = Calculator()
        let mask = makeMaskImage(width: 1, height: 1, alphaByPixel: [255])
        let intrinsics = makeIntrinsics(fx: 1000, fy: 1000)

        let metrics = calculator.calculateMetrics(
            from: (mask, [CGRect(x: 0, y: 0, width: 1, height: 1)]),
            depthMap: nil,
            confidenceMap: nil,
            cameraIntrinsics: intrinsics,
            imageOrientation: .up,
            model: .projection
        )

        #expect(metrics.areaMM2 == 0.0)
        #expect(metrics.diameterMM == 0.0)
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

@Suite("CalculatorHelper")
struct CalculatorHelperTests {

    // MARK: - median

    @Test func median_oddCount_returnsMiddleValue() {
        #expect(CalculatorHelper.median(of: [3, 1, 2]) == 2.0)
    }

    @Test func median_evenCount_returnsAverageOfTwoMiddles() {
        #expect(CalculatorHelper.median(of: [4, 1, 3, 2]) == 2.5)
    }

    @Test func median_singleValue_returnsThatValue() {
        #expect(CalculatorHelper.median(of: [7]) == 7.0)
    }

    @Test func median_duplicateValues_returnsDuplicate() {
        #expect(CalculatorHelper.median(of: [5, 5, 5, 5]) == 5.0)
    }

    // MARK: - sensorDimensions

    @Test func sensorDimensions_upOrientation_returnsOriginal() {
        let (w, h) = CalculatorHelper.sensorDimensions(
            normalizedWidth: 100,
            normalizedHeight: 50,
            orientation: .up
        )
        #expect(w == 100)
        #expect(h == 50)
    }

    @Test func sensorDimensions_downOrientation_returnsOriginal() {
        let (w, h) = CalculatorHelper.sensorDimensions(
            normalizedWidth: 100,
            normalizedHeight: 50,
            orientation: .down
        )
        #expect(w == 100)
        #expect(h == 50)
    }

    @Test func sensorDimensions_rightOrientation_swapsDimensions() {
        let (w, h) = CalculatorHelper.sensorDimensions(
            normalizedWidth: 100,
            normalizedHeight: 50,
            orientation: .right
        )
        #expect(w == 50)
        #expect(h == 100)
    }

    @Test func sensorDimensions_leftOrientation_swapsDimensions() {
        let (w, h) = CalculatorHelper.sensorDimensions(
            normalizedWidth: 100,
            normalizedHeight: 50,
            orientation: .left
        )
        #expect(w == 50)
        #expect(h == 100)
    }

    // MARK: - normalizedToSensor

    @Test func normalizedToSensor_upOrientation_isIdentity() {
        let (sx, sy) = CalculatorHelper.normalizedToSensor(
            nx: 3, ny: 7,
            normalizedWidth: 10, normalizedHeight: 20,
            orientation: .up
        )
        #expect(sx == 3)
        #expect(sy == 7)
    }

    @Test func normalizedToSensor_rightOrientation_mapsAsExpected() {
        // right: (nx, ny) → (ny, normalizedWidth - 1 - nx)
        let (sx, sy) = CalculatorHelper.normalizedToSensor(
            nx: 2, ny: 4,
            normalizedWidth: 10, normalizedHeight: 20,
            orientation: .right
        )
        #expect(sx == 4)
        #expect(sy == 7)
    }

    @Test func normalizedToSensor_leftOrientation_mapsAsExpected() {
        // left: (nx, ny) → (normalizedHeight - 1 - ny, nx)
        let (sx, sy) = CalculatorHelper.normalizedToSensor(
            nx: 2, ny: 4,
            normalizedWidth: 10, normalizedHeight: 20,
            orientation: .left
        )
        #expect(sx == 15)
        #expect(sy == 2)
    }

    @Test func normalizedToSensor_downOrientation_isPointReflection() {
        // down: (nx, ny) → (W-1-nx, H-1-ny)
        let (sx, sy) = CalculatorHelper.normalizedToSensor(
            nx: 2, ny: 4,
            normalizedWidth: 10, normalizedHeight: 20,
            orientation: .down
        )
        #expect(sx == 7)
        #expect(sy == 15)
    }

    @Test func normalizedToSensor_upMirrored_flipsHorizontally() {
        let (sx, sy) = CalculatorHelper.normalizedToSensor(
            nx: 2, ny: 4,
            normalizedWidth: 10, normalizedHeight: 20,
            orientation: .upMirrored
        )
        #expect(sx == 7)
        #expect(sy == 4)
    }

    // MARK: - clampedPixelBounds

    @Test func clampedPixelBounds_rectInside_returnsInclusiveBounds() {
        let bounds = CalculatorHelper.clampedPixelBounds(
            for: CGRect(x: 2, y: 3, width: 4, height: 5),
            width: 100,
            height: 100
        )

        #expect(bounds?.minX == 2)
        #expect(bounds?.minY == 3)
        // maxX = ceil(6) - 1 = 5, maxY = ceil(8) - 1 = 7
        #expect(bounds?.maxX == 5)
        #expect(bounds?.maxY == 7)
    }

    @Test func clampedPixelBounds_rectOverflowsImage_clampsToEdges() {
        let bounds = CalculatorHelper.clampedPixelBounds(
            for: CGRect(x: -5, y: -5, width: 100, height: 100),
            width: 10,
            height: 10
        )

        #expect(bounds?.minX == 0)
        #expect(bounds?.minY == 0)
        #expect(bounds?.maxX == 9)
        #expect(bounds?.maxY == 9)
    }

    @Test func clampedPixelBounds_rectEntirelyOutside_returnsNil() {
        let bounds = CalculatorHelper.clampedPixelBounds(
            for: CGRect(x: 50, y: 50, width: 10, height: 10),
            width: 10,
            height: 10
        )
        #expect(bounds == nil)
    }

    @Test func clampedPixelBounds_zeroSizedRect_returnsNil() {
        let bounds = CalculatorHelper.clampedPixelBounds(
            for: CGRect(x: 5, y: 5, width: 0, height: 0),
            width: 10,
            height: 10
        )
        // minX = 5, maxX = ceil(5)-1 = 4 → minX > maxX
        #expect(bounds == nil)
    }

    // MARK: - convexHull

    @Test func convexHull_twoPoints_returnsInputUnchanged() {
        let points = [CGPoint(x: 0, y: 0), CGPoint(x: 3, y: 4)]
        let hull = CalculatorHelper.convexHull(of: points)
        #expect(hull.count == 2)
    }

    @Test func convexHull_squareCorners_returnsAllFourVertices() {
        let points = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 1, y: 0),
            CGPoint(x: 1, y: 1),
            CGPoint(x: 0, y: 1)
        ]
        let hull = CalculatorHelper.convexHull(of: points)
        #expect(hull.count == 4)
    }

    @Test func convexHull_interiorPointIsOmitted() {
        let points = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 2, y: 0),
            CGPoint(x: 2, y: 2),
            CGPoint(x: 0, y: 2),
            CGPoint(x: 1, y: 1) // inside the square
        ]
        let hull = CalculatorHelper.convexHull(of: points)
        #expect(hull.count == 4)
        #expect(!hull.contains(CGPoint(x: 1, y: 1)))
    }

    @Test func convexHull_collinearPoints_returnsOnlyEndpoints() {
        let points = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 1, y: 0),
            CGPoint(x: 2, y: 0)
        ]
        let hull = CalculatorHelper.convexHull(of: points)
        #expect(hull.count == 2)
        #expect(hull.contains(CGPoint(x: 0, y: 0)))
        #expect(hull.contains(CGPoint(x: 2, y: 0)))
    }

    // MARK: - maxPairwiseSquaredDistance

    @Test func maxPairwiseSquaredDistance_twoPoints_returnsScaledSquaredDistance() {
        let points = [CGPoint(x: 0, y: 0), CGPoint(x: 3, y: 4)]
        let result = CalculatorHelper.maxPairwiseSquaredDistance(
            in: points,
            invFx: 1.0,
            invFy: 1.0
        )
        // 3² + 4² = 25
        #expect(abs(result - 25.0) < 1e-9)
    }

    @Test func maxPairwiseSquaredDistance_unitSquare_returnsDiagonalSquared() {
        let points = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 1, y: 0),
            CGPoint(x: 1, y: 1),
            CGPoint(x: 0, y: 1)
        ]
        let result = CalculatorHelper.maxPairwiseSquaredDistance(
            in: points,
            invFx: 1.0,
            invFy: 1.0
        )
        // diagonal² = 1² + 1² = 2
        #expect(abs(result - 2.0) < 1e-9)
    }

    @Test func maxPairwiseSquaredDistance_scalesByInverseFocalLengths() {
        let points = [CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 0)]
        let result = CalculatorHelper.maxPairwiseSquaredDistance(
            in: points,
            invFx: 1.0 / 1000.0,
            invFy: 1.0 / 1000.0
        )
        // (100 / 1000)² = 0.01
        #expect(abs(result - 0.01) < 1e-9)
    }
}
