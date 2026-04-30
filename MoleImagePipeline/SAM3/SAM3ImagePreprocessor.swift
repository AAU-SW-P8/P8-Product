//
//  SAM3ImagePreprocessor.swift
//  P8-Product
//
//  Converts a UIImage into the Float16 tensor that the SAM 3.1 vision encoder expects.
//

import CoreImage
import CoreML
import CoreVideo
import UIKit

/// Resizes and normalizes images for the SAM 3.1 vision encoder.
/// The encoder expects a `[1, 3, 1008, 1008]` Float16 tensor in RGB order
/// Normalized with `mean=0.5, std=0.5` (i.e. pixel values mapped from `[0,255]`to `[-1, 1]`).
final class SAM3ImagePreprocessor {

    /// Side length (in pixels) of the square input the vision encoder expects.
    static let inputSize: Int = 1008

    private let ciContext: CIContext = CIContext()

    /// Preprocesses an image into the Float16 tensor consumed by the vision encoder.
    ///
    /// - Parameter image: The source image. Must back a valid `CGImage`.
    /// - Returns: A `[1, 3, inputSize, inputSize]` Float16 `MLMultiArray`.
    /// - Throws: `PipelineError.invalidImage` if the image has no `CGImage`,
    ///   or `PipelineError.renderFailed` if the pixel buffer cannot be created.
    func preprocess(_ image: UIImage) throws -> MLMultiArray {
        guard let cgImage = image.cgImage else { throw PipelineError.invalidImage }

        let size: Int = Self.inputSize
        let pixelBuffer: CVPixelBuffer = try makeResizedPixelBuffer(from: cgImage, size: size)
        return try makeNormalizedTensor(from: pixelBuffer, size: size)
    }

    /// Resizes a CGImage into a square `CVPixelBuffer`.
    ///
    /// - Parameters:
    ///   - cgImage: The source image to resize.
    ///   - size: The target side length in pixels for the square output buffer.
    /// - Returns: A BGRA `CVPixelBuffer` of dimensions `size × size`.
    /// - Throws: `PipelineError.renderFailed` if the pixel buffer cannot be allocated.
    private func makeResizedPixelBuffer(from cgImage: CGImage, size: Int) throws -> CVPixelBuffer {
        let originalCI: CIImage = CIImage(cgImage: cgImage)
        let scaleX: CGFloat = CGFloat(size) / originalCI.extent.width
        let scaleY: CGFloat = CGFloat(size) / originalCI.extent.height
        let resizedCI: CIImage = originalCI.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        let bufferAttributes: [String: Any] = [
            // Make sure we can convert back to CGImage
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            // Allows us to use Apple's standard 2D drawing tools
            // to write directly into this raw memory block.
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            // Allows the CPU, GPU, and the NPU to all access the exact same memory bucket
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]

        // Allocate memory for the pixel buffer
        // Returns a pointer to the memory
        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, size, size,
                            kCVPixelFormatType_32BGRA,
                            bufferAttributes as CFDictionary,
                            &pixelBuffer)

        guard let buffer: CVPixelBuffer = pixelBuffer else {
            print("CVPixelBufferCreate failed for size \(size)×\(size)")
            throw PipelineError.renderFailed
        }
        // Process image and save it into memory
        ciContext.render(resizedCI, to: buffer)
        return buffer
    }

    /// Takes the raw, physical pixels from the CVPixelBuffer  created and
    /// translates them into the exact mathematical format (a Float16 tensor) that the SAM 3.1 neural network can read.
    /// Specifically converts a BGRA `CVPixelBuffer` into a Float16 `[1, 3, H, W]` tensor in RGB order, normalized to `[-1, 1]
    /// SAM 3.1 expects `Normalize(mean=[0.5,0.5,0.5], std=[0.5,0.5,0.5])`, which simplifies to`pixel/127.5 - 1`.
    ///
    /// - Parameters:
    ///   - pixelBuffer: A BGRA `CVPixelBuffer` containing the resized image pixels.
    ///   - size: The side length of the square buffer (must match the buffer's dimensions).
    /// - Returns: A `[1, 3, size, size]` Float16 `MLMultiArray` in RGB channel order, normalized to `[-1, 1]`.
    /// - Throws: `PipelineError.renderFailed` if the pixel buffer's base address is inaccessible.
    private func makeNormalizedTensor(from pixelBuffer: CVPixelBuffer, size: Int) throws -> MLMultiArray {
        // Create an empty tensor. Shape is [1 image, 3 colors, Height, Width]
        let array: MLMultiArray = try MLMultiArray(shape: [1, 3, size as NSNumber, size as NSNumber], dataType: .float16)

        // Lock the physical memory so the CPU can read it safely (no interference from GPU)
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)

        // Guarantee that the memory unlocks when this function finishes, even if an error happens.
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        // Find the exact memory address where the very first pixel is stored.
        guard let baseAddress: UnsafeMutableRawPointer = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            print("CVPixelBufferGetBaseAddress returned nil")
            throw PipelineError.renderFailed
        }

        // Find out exactly how many bytes make up one horizontal row
        let bytesPerRow: Int = CVPixelBufferGetBytesPerRow(pixelBuffer)

        // Tell Swift to treat that raw memory address as a list of 8-bit integers
        let bytes: UnsafeMutablePointer<UInt8> = baseAddress.assumingMemoryBound(to: UInt8.self)
        let hw: Int = size * size

        // Get a direct memory pointer to our empty tensor
        let dataPtr: UnsafeMutablePointer<Float16> = array.dataPointer.bindMemory(to: Float16.self, capacity: 3 * hw)

        // Our math constants to convert [0 to 255] into [-1.0 to +1.0].
        let scaleFactor: Float = 127.5
        let offsetValue: Float = 1.0

        // Format is BGRA (Blue, Green, Red, Alpha = 4 bytes per pixel)
        let bytesPerPixel: Int = 4

        // Loop through every row (y)
        for y: Int in 0..<size {
            // and loop through every pixel (x) in that row.
            for x: Int in 0..<size {
                // Calculate exactly which byte this specific pixel starts at
                let pixelOffset: Int = y * bytesPerRow + x * bytesPerPixel
                // Read the Blue, Green, and Red bytes
                // turn them into Floats,
                // and do the normalization.
                let b: Float = Float(bytes[pixelOffset])     / scaleFactor - offsetValue
                let g: Float = Float(bytes[pixelOffset + 1]) / scaleFactor - offsetValue
                let r: Float = Float(bytes[pixelOffset + 2]) / scaleFactor - offsetValue

                // Calculate the 1D position of this pixel inside the flat AI tensor
                let spatial: Int = y * size + x

                // Write the Red, Green, and Blue numbers into their own separate color blocks
                dataPtr[0 * hw + spatial] = Float16(r) // Block 0: All Reds
                dataPtr[1 * hw + spatial] = Float16(g) // Block 1: All Greens
                dataPtr[2 * hw + spatial] = Float16(b) // Block 2: All Blues
            }
        }

        return array
    }
}
