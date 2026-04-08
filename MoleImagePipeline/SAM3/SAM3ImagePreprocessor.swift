//
//  SAM3ImagePreprocessor.swift
//  P8-Product
//
//  Converts a UIImage into the Float16 tensor that the SAM 3.1 vision encoder
//  expects. Lives apart from `MoleSegmentor` because the math (resize +
//  BGRA→RGB + ImageNet-style normalization) is independent of the model
//  pipeline and worth testing on its own.
//

import CoreImage
import CoreML
import CoreVideo
import UIKit

/// Resizes and normalizes images for the SAM 3.1 vision encoder.
///
/// The encoder expects a `[1, 3, 1008, 1008]` Float16 tensor in RGB order,
/// normalized with `mean=0.5, std=0.5` (i.e. pixel values mapped from `[0,255]`
/// to `[-1, 1]`). Note that the resize is **non-uniform**: aspect ratio is
/// distorted to fit the square input. This matches the official SAM 3.1
/// preprocessing pipeline.
final class SAM3ImagePreprocessor {

    /// Side length (in pixels) of the square input the vision encoder expects.
    static let inputSize = 1008

    private let ciContext = CIContext()

    /// Preprocesses an image into the Float16 tensor consumed by the vision encoder.
    ///
    /// - Parameter image: The source image. Must back a valid `CGImage`.
    /// - Returns: A `[1, 3, inputSize, inputSize]` Float16 `MLMultiArray`.
    /// - Throws: `PipelineError.invalidImage` if the image has no `CGImage`,
    ///   or `PipelineError.renderFailed` if the pixel buffer cannot be created.
    func preprocess(_ image: UIImage) throws -> MLMultiArray {
        guard let cgImage = image.cgImage else { throw PipelineError.invalidImage }

        let size = Self.inputSize
        let pixelBuffer = try makeResizedPixelBuffer(from: cgImage, size: size)
        return try makeNormalizedTensor(from: pixelBuffer, size: size)
    }

    /// Resizes a CGImage into a square BGRA `CVPixelBuffer`.
    ///
    /// The resize is non-uniform — anything that isn't already square will be
    /// stretched. This matches the SAM 3.1 reference implementation.
    private func makeResizedPixelBuffer(from cgImage: CGImage, size: Int) throws -> CVPixelBuffer {
        let originalCI = CIImage(cgImage: cgImage)
        let scaleX = CGFloat(size) / originalCI.extent.width
        let scaleY = CGFloat(size) / originalCI.extent.height
        let resizedCI = originalCI.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        let bufferAttributes: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]

        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, size, size,
                            kCVPixelFormatType_32BGRA,
                            bufferAttributes as CFDictionary,
                            &pixelBuffer)

        guard let buffer = pixelBuffer else {
            print("❌ CVPixelBufferCreate failed for size \(size)×\(size)")
            throw PipelineError.renderFailed
        }
        ciContext.render(resizedCI, to: buffer)
        return buffer
    }

    /// Converts a BGRA `CVPixelBuffer` into a Float16 `[1, 3, H, W]` tensor in
    /// RGB order, normalized to `[-1, 1]`.
    ///
    /// SAM 3.1 expects `Normalize(mean=[0.5,0.5,0.5], std=[0.5,0.5,0.5])`,
    /// which simplifies to `pixel/127.5 - 1`.
    private func makeNormalizedTensor(from pixelBuffer: CVPixelBuffer, size: Int) throws -> MLMultiArray {
        let array = try MLMultiArray(shape: [1, 3, size as NSNumber, size as NSNumber], dataType: .float16)

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            print("❌ CVPixelBufferGetBaseAddress returned nil")
            throw PipelineError.renderFailed
        }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let bytes = baseAddress.assumingMemoryBound(to: UInt8.self)
        let hw = size * size

        // Direct Float16 pointer write — we own this array, so the binding is safe.
        let dataPtr = array.dataPointer.bindMemory(to: Float16.self, capacity: 3 * hw)

        for y in 0..<size {
            for x in 0..<size {
                let pixelOffset = y * bytesPerRow + x * 4
                // BGRA → RGB, normalized to [-1, 1].
                let b = Float(bytes[pixelOffset])     / 127.5 - 1.0
                let g = Float(bytes[pixelOffset + 1]) / 127.5 - 1.0
                let r = Float(bytes[pixelOffset + 2]) / 127.5 - 1.0

                let spatial = y * size + x
                dataPtr[0 * hw + spatial] = Float16(r)
                dataPtr[1 * hw + spatial] = Float16(g)
                dataPtr[2 * hw + spatial] = Float16(b)
            }
        }

        return array
    }
}
