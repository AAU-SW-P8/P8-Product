import CoreGraphics
import CoreVideo
import Testing
import UIKit
@testable import P8_Product

@Suite("DistanceLookup")
struct DistanceLookupTests {

    @Test func mmPerPixel_exactEntry_returnsEntryValue() {
        let lookup = DistanceLookup(entries: [
            DistanceLookup.Entry(distanceMeters: 0.1, mmPerPixel: 0.1),
            DistanceLookup.Entry(distanceMeters: 1.0, mmPerPixel: 1.0)
        ])
        #expect(abs(lookup.mmPerPixel(atDistance: 1.0) - 1.0) < 1e-9)
        #expect(abs(lookup.mmPerPixel(atDistance: 0.1) - 0.1) < 1e-9)
    }

    @Test func mmPerPixel_betweenEntries_interpolatesLinearly() {
        let lookup = DistanceLookup(entries: [
            DistanceLookup.Entry(distanceMeters: 0.2, mmPerPixel: 0.4),
            DistanceLookup.Entry(distanceMeters: 0.4, mmPerPixel: 0.8)
        ])
        // Midpoint between 0.2 and 0.4 → mmPerPixel halfway between 0.4 and 0.8.
        #expect(abs(lookup.mmPerPixel(atDistance: 0.3) - 0.6) < 1e-9)
    }

    @Test func mmPerPixel_belowRange_clampsToFirstEntry() {
        let lookup = DistanceLookup(entries: [
            DistanceLookup.Entry(distanceMeters: 0.1, mmPerPixel: 0.25),
            DistanceLookup.Entry(distanceMeters: 1.0, mmPerPixel: 2.0)
        ])
        #expect(lookup.mmPerPixel(atDistance: 0.01) == 0.25)
    }

    @Test func mmPerPixel_aboveRange_clampsToLastEntry() {
        let lookup = DistanceLookup(entries: [
            DistanceLookup.Entry(distanceMeters: 0.1, mmPerPixel: 0.25),
            DistanceLookup.Entry(distanceMeters: 1.0, mmPerPixel: 2.0)
        ])
        #expect(lookup.mmPerPixel(atDistance: 5.0) == 2.0)
    }

    @Test func init_unsortedEntries_areSortedByDistance() {
        let lookup = DistanceLookup(entries: [
            DistanceLookup.Entry(distanceMeters: 1.0, mmPerPixel: 2.0),
            DistanceLookup.Entry(distanceMeters: 0.1, mmPerPixel: 0.1)
        ])
        #expect(lookup.entries.first?.distanceMeters == 0.1)
        #expect(lookup.entries.last?.distanceMeters == 1.0)
    }

    @Test func mmPerPixel_emptyTable_returnsZero() {
        let lookup = DistanceLookup(entries: [])
        #expect(lookup.mmPerPixel(atDistance: 1.0) == 0)
    }
}

@Suite("CalculatorLinearHelper")
struct CalculatorLinearHelperTests {

    @Test func maxPairwiseSquaredPixelDistance_twoPoints_returnsSquaredEuclidean() {
        let points = [CGPoint(x: 0, y: 0), CGPoint(x: 3, y: 4)]
        let result = CalculatorLinearHelper.maxPairwiseSquaredPixelDistance(in: points)
        #expect(abs(result - 25.0) < 1e-9)
    }

    @Test func maxPairwiseSquaredPixelDistance_unitSquare_returnsDiagonalSquared() {
        let points = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 1, y: 0),
            CGPoint(x: 1, y: 1),
            CGPoint(x: 0, y: 1)
        ]
        let result = CalculatorLinearHelper.maxPairwiseSquaredPixelDistance(in: points)
        #expect(abs(result - 2.0) < 1e-9)
    }

    @Test func maxPairwiseSquaredPixelDistance_singlePoint_returnsZero() {
        let result = CalculatorLinearHelper.maxPairwiseSquaredPixelDistance(in: [CGPoint(x: 5, y: 5)])
        #expect(result == 0)
    }
}

@Suite("CalculatorLinear")
struct CalculatorLinearTests {

    // Identity lookup: at 1 m, one pixel is 1 mm — keeps arithmetic easy.
    private func identityLookup() -> DistanceLookup {
        DistanceLookup(entries: [
            DistanceLookup.Entry(distanceMeters: 0.05, mmPerPixel: 0.05),
            DistanceLookup.Entry(distanceMeters: 1.00, mmPerPixel: 1.00),
            DistanceLookup.Entry(distanceMeters: 2.00, mmPerPixel: 2.00)
        ])
    }

    // MARK: - Area

    @Test func calculateArea_singlePixelAtOneMeter_returnsOneSquareMillimeter() throws {
        let calculator = CalculatorLinear(distanceLookup: identityLookup())
        let mask = makeMaskImage(width: 2, height: 2, alphaByPixel: [255, 0,
                                                                      0,   0])
        let depth = try makeDepthPixelBuffer(width: 2, height: 2, values: [1, 1,
                                                                             1, 1])

        let area = calculator.calculateMetrics(
            from: (mask, [CGRect(x: 0, y: 0, width: 2, height: 2)]),
            depthMap: depth,
            confidenceMap: nil,
            imageOrientation: .up
        ).areaMM2

        // 1 masked pixel × (1 mm/pixel)² = 1 mm².
        #expect(abs(Double(area) - 1.0) < 1e-6)
    }

    @Test func calculateArea_fullAlpha_matchesExpected() throws {
        let calculator = CalculatorLinear(distanceLookup: identityLookup())
        let mask = makeMaskImage(width: 2, height: 2, alphaByPixel: [127, 127,
                                                                      127, 127])
        let depth = try makeDepthPixelBuffer(width: 2, height: 2, values: [1, 1,
                                                                             1, 1])

        let area = calculator.calculateMetrics(
            from: (mask, [CGRect(x: 0, y: 0, width: 2, height: 2)]),
            depthMap: depth,
            confidenceMap: nil,
            imageOrientation: .up
        ).areaMM2

        // prob = 127 / 127.5 ≈ 0.996, 4 pixels, mm/pixel = 1.
        let probPerPixel = 127.0 / 127.5
        let expected = 4.0 * probPerPixel * 1.0 * 1.0
        #expect(abs(Double(area) - expected) < 1e-6)
    }

    @Test func calculateArea_partialAlpha_contributesProportionally() throws {
        let calculator = CalculatorLinear(distanceLookup: identityLookup())
        let mask = makeMaskImage(width: 1, height: 1, alphaByPixel: [64])
        let depth = try makeDepthPixelBuffer(width: 1, height: 1, values: [1])

        let area = calculator.calculateMetrics(
            from: (mask, [CGRect(x: 0, y: 0, width: 1, height: 1)]),
            depthMap: depth,
            confidenceMap: nil,
            imageOrientation: .up
        ).areaMM2

        let prob = 64.0 / 127.5
        #expect(abs(Double(area) - prob) < 1e-6)
    }

    @Test func calculateArea_medianDepthDrivesLookup() throws {
        // 3 pixels, depths [0.20, 0.20, 0.50]. Median = 0.20, which the lookup
        // maps (linearly between 0.05 and 1.0) to mmPerPixel ≈ 0.2026.
        let calculator = CalculatorLinear(distanceLookup: identityLookup())
        let mask = makeMaskImage(width: 3, height: 1, alphaByPixel: [255, 255, 255])
        let depth = try makeDepthPixelBuffer(width: 3, height: 1, values: [0.20, 0.20, 0.50])

        let area = calculator.calculateMetrics(
            from: (mask, [CGRect(x: 0, y: 0, width: 3, height: 1)]),
            depthMap: depth,
            confidenceMap: nil,
            imageOrientation: .up
        ).areaMM2

        let medianDepth = 0.20
        let low = DistanceLookup.Entry(distanceMeters: 0.05, mmPerPixel: 0.05)
        let high = DistanceLookup.Entry(distanceMeters: 1.00, mmPerPixel: 1.00)
        let t = (medianDepth - low.distanceMeters) / (high.distanceMeters - low.distanceMeters)
        let mmPerPixel = low.mmPerPixel + t * (high.mmPerPixel - low.mmPerPixel)
        let expected = 3.0 * mmPerPixel * mmPerPixel
        #expect(abs(Double(area) - expected) < 1e-6)
    }

    @Test func calculateArea_scalesWithLookupValue() throws {
        // Custom lookup: 2 mm/pixel at 1 m → area must scale by 4.
        let lookup = DistanceLookup(entries: [
            DistanceLookup.Entry(distanceMeters: 0.5, mmPerPixel: 1.0),
            DistanceLookup.Entry(distanceMeters: 1.0, mmPerPixel: 2.0),
            DistanceLookup.Entry(distanceMeters: 2.0, mmPerPixel: 4.0)
        ])
        let calculator = CalculatorLinear(distanceLookup: lookup)
        let mask = makeMaskImage(width: 1, height: 1, alphaByPixel: [255])
        let depth = try makeDepthPixelBuffer(width: 1, height: 1, values: [1])

        let area = calculator.calculateMetrics(
            from: (mask, [CGRect(x: 0, y: 0, width: 1, height: 1)]),
            depthMap: depth,
            confidenceMap: nil,
            imageOrientation: .up
        ).areaMM2

        // 1 pixel × (2 mm/pixel)² = 4 mm².
        #expect(abs(Double(area) - 4.0) < 1e-6)
    }

    @Test func calculateArea_allDepthsInvalid_returnsZero() throws {
        let calculator = CalculatorLinear(distanceLookup: identityLookup())
        let mask = makeMaskImage(width: 2, height: 1, alphaByPixel: [255, 255])
        let depth = try makeDepthPixelBuffer(width: 2, height: 1, values: [0.01, 3.0])

        let area = calculator.calculateMetrics(
            from: (mask, [CGRect(x: 0, y: 0, width: 2, height: 1)]),
            depthMap: depth,
            confidenceMap: nil,
            imageOrientation: .up
        ).areaMM2

        #expect(area == 0.0)
    }

    @Test func calculateArea_lowConfidenceDepth_excludedFromMedian() throws {
        let calculator = CalculatorLinear(distanceLookup: identityLookup())
        let mask = makeMaskImage(width: 2, height: 1, alphaByPixel: [255, 255])
        let depth = try makeDepthPixelBuffer(width: 2, height: 1, values: [0.20, 1.00])
        let confidence = try makeConfidencePixelBuffer(width: 2, height: 1, values: [0, 2])

        let area = calculator.calculateMetrics(
            from: (mask, [CGRect(x: 0, y: 0, width: 2, height: 1)]),
            depthMap: depth,
            confidenceMap: confidence,
            imageOrientation: .up
        ).areaMM2

        // Only the high-confidence 1 m depth survives → mmPerPixel = 1.
        let expected = 2.0 * 1.0 * 1.0
        #expect(abs(Double(area) - expected) < 1e-6)
    }

    // MARK: - Guard paths

    @Test func calculateMetrics_nilDepthMap_returnsZeros() throws {
        let calculator = CalculatorLinear(distanceLookup: identityLookup())
        let mask = makeMaskImage(width: 1, height: 1, alphaByPixel: [255])

        let metrics = calculator.calculateMetrics(
            from: (mask, [CGRect(x: 0, y: 0, width: 1, height: 1)]),
            depthMap: nil,
            confidenceMap: nil,
            imageOrientation: .up
        )

        #expect(metrics.areaMM2 == 0.0)
        #expect(metrics.diameterMM == 0.0)
    }

    @Test func calculateMetrics_emptyBoundingBoxes_returnsZeros() throws {
        let calculator = CalculatorLinear(distanceLookup: identityLookup())
        let mask = makeMaskImage(width: 1, height: 1, alphaByPixel: [255])
        let depth = try makeDepthPixelBuffer(width: 1, height: 1, values: [1])

        let metrics = calculator.calculateMetrics(
            from: (mask, []),
            depthMap: depth,
            confidenceMap: nil,
            imageOrientation: .up
        )

        #expect(metrics.areaMM2 == 0.0)
        #expect(metrics.diameterMM == 0.0)
    }

    // MARK: - Diameter

    @Test func calculateDiameter_twoAdjacentPixels_returnsOneMillimeter() throws {
        let calculator = CalculatorLinear(distanceLookup: identityLookup())
        let mask = makeMaskImage(width: 2, height: 1, alphaByPixel: [255, 255])
        let depth = try makeDepthPixelBuffer(width: 2, height: 1, values: [1, 1])

        let diameter = calculator.calculateMetrics(
            from: (mask, [CGRect(x: 0, y: 0, width: 2, height: 1)]),
            depthMap: depth,
            confidenceMap: nil,
            imageOrientation: .up
        ).diameterMM

        // sqrt(1 px²) × 1 mm/px = 1 mm.
        #expect(abs(Double(diameter) - 1.0) < 1e-6)
    }

    @Test func calculateDiameter_singlePixel_returnsZero() throws {
        let calculator = CalculatorLinear(distanceLookup: identityLookup())
        let mask = makeMaskImage(width: 1, height: 1, alphaByPixel: [255])
        let depth = try makeDepthPixelBuffer(width: 1, height: 1, values: [1])

        let diameter = calculator.calculateMetrics(
            from: (mask, [CGRect(x: 0, y: 0, width: 1, height: 1)]),
            depthMap: depth,
            confidenceMap: nil,
            imageOrientation: .up
        ).diameterMM

        #expect(diameter == 0.0)
    }

    @Test func calculateDiameter_scalesWithLookupValue() throws {
        let lookup = DistanceLookup(entries: [
            DistanceLookup.Entry(distanceMeters: 0.5, mmPerPixel: 1.0),
            DistanceLookup.Entry(distanceMeters: 1.0, mmPerPixel: 2.0),
            DistanceLookup.Entry(distanceMeters: 2.0, mmPerPixel: 4.0)
        ])
        let calculator = CalculatorLinear(distanceLookup: lookup)
        let mask = makeMaskImage(width: 2, height: 1, alphaByPixel: [255, 255])
        let depth = try makeDepthPixelBuffer(width: 2, height: 1, values: [1, 1])

        let diameter = calculator.calculateMetrics(
            from: (mask, [CGRect(x: 0, y: 0, width: 2, height: 1)]),
            depthMap: depth,
            confidenceMap: nil,
            imageOrientation: .up
        ).diameterMM

        // 1 px span × 2 mm/px = 2 mm.
        #expect(abs(Double(diameter) - 2.0) < 1e-6)
    }

    // MARK: - Combined

    @Test func calculateMetrics_returnsBothAreaAndDiameter() throws {
        let calculator = CalculatorLinear(distanceLookup: identityLookup())
        let mask = makeMaskImage(width: 2, height: 1, alphaByPixel: [255, 255])
        let depth = try makeDepthPixelBuffer(width: 2, height: 1, values: [1, 1])

        let metrics = calculator.calculateMetrics(
            from: (mask, [CGRect(x: 0, y: 0, width: 2, height: 1)]),
            depthMap: depth,
            confidenceMap: nil,
            imageOrientation: .up
        )

        // 2 pixels × 1 mm² each → 2 mm²; 1 pixel span × 1 mm/px → 1 mm.
        #expect(abs(Double(metrics.areaMM2) - 2.0) < 1e-6)
        #expect(abs(Double(metrics.diameterMM) - 1.0) < 1e-6)
    }

    // MARK: - Test helpers

    private func makeMaskImage(width: Int, height: Int, alphaByPixel: [UInt8]) -> UIImage {
        precondition(alphaByPixel.count == width * height)

        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        for i in 0..<alphaByPixel.count {
            let a = alphaByPixel[i]
            let o = i * 4
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
            throw NSError(domain: "CalculatorLinearTests", code: Int(status))
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            throw NSError(domain: "CalculatorLinearTests", code: -1)
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
            throw NSError(domain: "CalculatorLinearTests", code: Int(status))
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            throw NSError(domain: "CalculatorLinearTests", code: -1)
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
