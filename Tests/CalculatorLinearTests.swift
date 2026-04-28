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

/// Linear-strategy tests. Sampling-pipeline behavior (alpha weighting,
/// confidence filtering, depth-range guards, nil-input guards) is exercised
/// once via the projection model in `CalculatorTests`; this suite only covers
/// the math that's specific to the linear lookup-driven strategy.
///
/// `DistanceLookup.default` cannot be replaced through the public router, so
/// these tests pick depths whose lookup values are known exactly.
@Suite("CalculatorLinear")
struct CalculatorLinearTests {

    // Exact entries from DistanceLookup.default used below.
    private let mmPerPixelAt30cm = 0.2121
    private let mmPerPixelAt20cm = 0.1396

    @Test func calculateArea_singlePixel_usesLookupValueAtMedianDepth() throws {
        let calculator = Calculator()
        let mask = makeMaskImage(width: 1, height: 1, alphaByPixel: [255])
        let depth = try makeDepthPixelBuffer(width: 1, height: 1, values: [0.30])

        let area = calculator.calculateMetrics(
            from: (mask, [CGRect(x: 0, y: 0, width: 1, height: 1)]),
            depthMap: depth,
            confidenceMap: nil,
            imageOrientation: .up,
            model: .linear
        ).areaMM2

        // 1 pixel × (0.2121 mm/px)².
        let expected = mmPerPixelAt30cm * mmPerPixelAt30cm
        #expect(abs(Double(area) - expected) < 1e-6)
    }

    @Test func calculateArea_medianDepthDrivesLookup_outlierIgnored() throws {
        // Depths [0.30, 0.30, 0.50]. Median = 0.30, so the 0.50 m outlier
        // must not shift the mm/pixel factor used for area.
        let calculator = Calculator()
        let mask = makeMaskImage(width: 3, height: 1, alphaByPixel: [255, 255, 255])
        let depth = try makeDepthPixelBuffer(width: 3, height: 1, values: [0.30, 0.30, 0.50])

        let area = calculator.calculateMetrics(
            from: (mask, [CGRect(x: 0, y: 0, width: 3, height: 1)]),
            depthMap: depth,
            confidenceMap: nil,
            imageOrientation: .up,
            model: .linear
        ).areaMM2

        let expected = 3.0 * mmPerPixelAt30cm * mmPerPixelAt30cm
        #expect(abs(Double(area) - expected) < 1e-6)
    }

    @Test func calculateArea_depthBelowCalibratedRange_clampsToFirstEntry() throws {
        // 0.10 m is a valid depth sample but below the lookup's calibrated
        // minimum (0.20 m), so mmPerPixel clamps to the first entry rather
        // than extrapolating.
        let calculator = Calculator()
        let mask = makeMaskImage(width: 1, height: 1, alphaByPixel: [255])
        let depth = try makeDepthPixelBuffer(width: 1, height: 1, values: [0.10])

        let area = calculator.calculateMetrics(
            from: (mask, [CGRect(x: 0, y: 0, width: 1, height: 1)]),
            depthMap: depth,
            confidenceMap: nil,
            imageOrientation: .up,
            model: .linear
        ).areaMM2

        let expected = mmPerPixelAt20cm * mmPerPixelAt20cm
        #expect(abs(Double(area) - expected) < 1e-6)
    }

    @Test func calculateDiameter_twoAdjacentPixels_usesLookupValue() throws {
        let calculator = Calculator()
        let mask = makeMaskImage(width: 2, height: 1, alphaByPixel: [255, 255])
        let depth = try makeDepthPixelBuffer(width: 2, height: 1, values: [0.30, 0.30])

        let diameter = calculator.calculateMetrics(
            from: (mask, [CGRect(x: 0, y: 0, width: 2, height: 1)]),
            depthMap: depth,
            confidenceMap: nil,
            imageOrientation: .up,
            model: .linear
        ).diameterMM

        // sqrt(1 px²) × 0.2121 mm/px = 0.2121 mm.
        #expect(abs(Double(diameter) - mmPerPixelAt30cm) < 1e-6)
    }

    @Test func calculateMetrics_returnsBothAreaAndDiameter() throws {
        let calculator = Calculator()
        let mask = makeMaskImage(width: 2, height: 1, alphaByPixel: [255, 255])
        let depth = try makeDepthPixelBuffer(width: 2, height: 1, values: [0.30, 0.30])

        let metrics = calculator.calculateMetrics(
            from: (mask, [CGRect(x: 0, y: 0, width: 2, height: 1)]),
            depthMap: depth,
            confidenceMap: nil,
            imageOrientation: .up,
            model: .linear
        )

        #expect(abs(Double(metrics.areaMM2) - 2.0 * mmPerPixelAt30cm * mmPerPixelAt30cm) < 1e-6)
        #expect(abs(Double(metrics.diameterMM) - mmPerPixelAt30cm) < 1e-6)
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
