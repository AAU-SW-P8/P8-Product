//
//  MaskRenderer.swift
//  P8-Product
//

import UIKit
import CoreML

/// Renders an `MLMultiArray` segmentation mask into a `UIImage` overlay.
///
/// SAM2.1 outputs a Float16 tensor of shape `[1, 3, H, W]` where:
/// - `1` — batch size (always 1 for single-image inference)
/// - `3` — number of candidate masks the decoder proposes
/// - `H` / `W` — mask height and width in pixels
///
/// For each pixel the highest logit across the 3 candidates is selected.
/// Positive logits are foreground; zero or negative are background.
struct MaskRenderer {

    /// RGBA colour used for foreground (mole) pixels.
    var foreground = RGBA(red: 255, green: 0, blue: 0, alpha: 128)

    /// RGBA colour used for background pixels.
    var background = RGBA(red: 0, green: 0, blue: 255, alpha: 64)

    // MARK: - Public

    /// Converts a SAM mask tensor to a coloured overlay image.
    ///
    /// - Parameters:
    ///   - maskArray: A Float16 `MLMultiArray` of shape `[1, 3, H, W]`.
    ///   - targetSize: The desired output size. The mask is scaled to fit if its
    ///     dimensions differ from `targetSize`.
    /// - Returns: A `UIImage` with foreground/background colouring.
    func render(_ maskArray: MLMultiArray, targetSize: CGSize) throws -> UIImage {
        precondition(maskArray.dataType == .float16, "Expected Float16 mask output")

        let shape     = maskArray.shape.map { $0.intValue }
        let maskCount = shape[1]  // 3 candidate masks
        let maskH     = shape[2]
        let maskW     = shape[3]

        // Build an RGBA pixel buffer from the mask logits
        let pixels = buildPixelBuffer(
            maskArray: maskArray,
            maskCount: maskCount,
            maskH: maskH,
            maskW: maskW
        )

        // Create a CGImage from the pixel buffer
        let cgImage = try createCGImage(from: pixels, width: maskW, height: maskH)
        let maskImage = UIImage(cgImage: cgImage)

        // Resize to target size if needed
        guard maskImage.size != targetSize else { return maskImage }
        return resize(maskImage, to: targetSize)
    }

    // MARK: - Private

    /// Iterates every pixel, picks the best logit across all candidate masks,
    /// and writes foreground or background colour into an RGBA buffer.
    private func buildPixelBuffer(
        maskArray: MLMultiArray,
        maskCount: Int,
        maskH: Int,
        maskW: Int
    ) -> [UInt8] {
        let ptr         = maskArray.dataPointer.assumingMemoryBound(to: Float16.self)
        let planeStride = maskH * maskW
        let bytesPerPixel = 4

        var pixels = [UInt8](repeating: 0, count: maskH * maskW * bytesPerPixel)

        for y in 0..<maskH {
            for x in 0..<maskW {
                let baseIndex  = y * maskW + x
                let pixelIndex = baseIndex * bytesPerPixel

                // Pick the highest logit across all candidate masks
                var bestValue = -Float16.infinity
                for m in 0..<maskCount {
                    let val = ptr[m * planeStride + baseIndex]
                    if val > bestValue { bestValue = val }
                }

                // Assign overlay colour based on whether the pixel is foreground
                let colour = bestValue > 0.0 ? foreground : background
                pixels[pixelIndex]     = colour.red
                pixels[pixelIndex + 1] = colour.green
                pixels[pixelIndex + 2] = colour.blue
                pixels[pixelIndex + 3] = colour.alpha
            }
        }

        return pixels
    }

    /// Creates a `CGImage` from a raw RGBA pixel buffer.
    private func createCGImage(from pixels: [UInt8], width: Int, height: Int) throws -> CGImage {
        let bytesPerPixel    = 4
        let bitsPerComponent = 8
        let bytesPerRow      = width * bytesPerPixel
        let colorSpace       = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo       = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        var mutablePixels = pixels
        guard let context = CGContext(
            data: &mutablePixels,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ), let cgImage = context.makeImage() else {
            throw MaskRenderError.contextCreationFailed
        }

        return cgImage
    }

    /// Resizes a `UIImage` to the given size.
    private func resize(_ image: UIImage, to size: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        image.draw(in: CGRect(origin: .zero, size: size))
        let resized = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        return resized
    }
}

// MARK: - Supporting Types

extension MaskRenderer {

    /// A simple RGBA colour value.
    struct RGBA {
        let red: UInt8
        let green: UInt8
        let blue: UInt8
        let alpha: UInt8
    }

    /// Errors that can occur during mask rendering.
    enum MaskRenderError: Error, LocalizedError {
        case contextCreationFailed

        var errorDescription: String? {
            "Failed to create CGContext for mask rendering"
        }
    }
}
