//
//  MoleSegmentor.swift
//  P8-Product
//
//  Created by Adomas Ciplys on 08/04/26.
//
//  Top-level orchestrator for the SAM 3.1 mole segmentation pipeline.
//  All heavy lifting lives in dedicated types under SAM3/ and Rendering/
//

import CoreML
import UIKit

/// Detects and segments moles in a photo using SAM 3.1
///
/// The pipeline is composed of three CoreML models:
///   1. **Vision encoder** — turns the image into FPN feature maps.
///   2. **Text encoder** — turns the prompt `"moles"` into a text embedding
///   3. **Decoder** — fuses the two and produces masks, boxes, and scores.
///
/// `MoleSegmentor`
class MoleSegmentor {

    // MARK: - Components

    private let visionEncoder: SAM3VisionEncoder
    private let decoder: SAM3Decoder
    private let textPrompt: SAM3TextPromptEncoder
    private let renderer: SegmentationRenderer

    // MARK: - Init

    /// Loads the three SAM 3.1 models from the app bundle and pre-encodes the fixed `"moles"` text prompt.
    /// This is `async` because compiling the vision encoder on first launch can take several seconds.
    ///
    /// - Throws: `PipelineError.modelNotFound` if any model resource is missing,
    ///     or any error CoreML raises while loading or running the text encoder.
    init() async throws {
        let models = try await SAM3Models.load()
        
        let preprocessor = SAM3ImagePreprocessor()
        
        // Encode image into tensor and cache result
        self.visionEncoder = SAM3VisionEncoder(model: models.visionEncoder, preprocessor: preprocessor)
        self.decoder = SAM3Decoder(model: models.decoder)
        self.textPrompt = try SAM3TextPromptEncoder(encoder: models.textEncoder)
        self.renderer = SegmentationRenderer()

        print("SAM3 models loaded and text encoded")
    }

    // MARK: - Public API

    /// Segments moles in the given image using the prompt `"moles"`.
    ///
    /// - Parameters:
    ///   - image: The full-resolution photo to segment.
    ///   - confidenceThreshold: Minimum decoder probability for a detection to be kept. Defaults to `0.3`.
    ///   - nmsThreshold: IoU threshold above which overlapping detections are suppressed. The default of `1.0` effectively disables NMS;
    ///     pass ~`0.5` for actual deduplication.
    /// - Returns: An annotated image (mask overlays + boxes + labels) and
    ///   the per-detection bounding boxes in pixel coordinates, or `nil` if
    ///   no detections passed the confidence threshold.
    func segment(image: UIImage, confidenceThreshold: Float = 0.3, nmsThreshold: Float = 1.0) throws -> (UIImage, [CGRect])? {
        let clock = ContinuousClock()

        // 1. Encode image (cached on repeat calls with the same UIImage instance).
        print("Encoding image…")
        var visionOutput: MLFeatureProvider!
        let encodeTime = try clock.measure {
            visionOutput = try visionEncoder.encode(image)
        }
        print("Encoding time: \(encodeTime)")

        // 2. Run the grounded mask decoder.
        var decoderOutput: SAM3DecoderOutput!
        let decodeTime = try clock.measure {
            decoderOutput = try decoder.run(visionFeatures: visionOutput, textFeatures: textPrompt.features)
        }
        print("Decoder execution time: \(decodeTime)")

        // 3. Filter by confidence.
        var detections = SAM3Detection.filterByConfidence(decoderOutput, threshold: confidenceThreshold)
        guard !detections.isEmpty else {
            print("No detections above threshold \(confidenceThreshold)")
            return nil
        }

        // 4. Drop overlapping detections.
        let beforeNms = detections.count
        detections = SAM3Detection.nonMaxSuppression(detections, iouThreshold: nmsThreshold)
        print("Found \(detections.count) moles (from \(beforeNms) candidates after NMS)")
        for det in detections {
            print("Detection \(det.index): prob=\(String(format: "%.3f", det.prob))")
        }

        // 5. Draw the annotated overlay.
        return renderer.renderOverlay(on: image, detections: detections, masks: decoderOutput.masks)
    }

    /// Drops the cached vision embeddings. Call this whenever the displayed
    /// image changes so the next `segment(_:)` call re-encodes from scratch.
    func clearCache() {
        visionEncoder.clearCache()
    }

    // MARK: - Private

    private func encodeImage(_ image: UIImage, modelSize: Int = 1024) async throws -> SAM2_1LargeImageEncoderFLOAT16Output {
            let imageHash = image.hashValue
            if let cached = cachedEncoderOutput, cachedImageHash == imageHash {
                return cached
            }

            guard let cgImage = image.cgImage else { throw PipelineError.invalidImage }

            // 1. Create the Pixel Buffer (this explicitly forces the safe 32BGRA format)
            let pixelBuffer = try createPixelBuffer(from: cgImage, size: modelSize)

            // 2. Pass the pixel buffer DIRECTLY to the encoder.
            // Do NOT use `MLMultiArray` and do NOT use the `imageWith: cgImage` helper!
            let input = SAM2_1LargeImageEncoderFLOAT16Input(image: pixelBuffer)
            let output = try await imageEncoder.prediction(input: input)

            cachedEncoderOutput = output
            cachedImageHash = imageHash

            return output
        }

    /**
     Helper method to create a CVPixelBuffer from a CGImage
     */
    private func createPixelBuffer(from cgImage: CGImage, size: Int) throws -> CVPixelBuffer {
        let originalCI = CIImage(cgImage: cgImage)
        let scaleX = CGFloat(size) / originalCI.extent.width
        let scaleY = CGFloat(size) / originalCI.extent.height
        let resizedCI = originalCI.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        let bufferAttributes: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:] // <-- ADD THIS LINE
        ]

        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(
            kCFAllocatorDefault,
            size,
            size,
            kCVPixelFormatType_32BGRA,
            bufferAttributes as CFDictionary,
            &pixelBuffer
        )

        guard let buffer = pixelBuffer else {
            throw PipelineError.renderFailed
        }

        ciContext.render(resizedCI, to: buffer)
        return buffer
    }

    /**
     Converts a CVPixelBuffer to MLMultiArray in the format [1, 3, height, width]
     The pixel values are normalized to [0, 1] range
     */
    private func convertPixelBufferToMLMultiArray(_ pixelBuffer: CVPixelBuffer, width: Int, height: Int) throws -> MLMultiArray {
        // Create MLMultiArray with shape [1, 3, height, width]
        guard let mlArray = try? MLMultiArray(shape: [1, 3, height as NSNumber, width as NSNumber], dataType: .float32) else {
            throw PipelineError.renderFailed
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            throw PipelineError.renderFailed
        }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)

        // Convert BGRA to RGB and normalize to [0, 1]
        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = y * bytesPerRow + x * 4

                let b = Float(buffer[pixelIndex]) / 255.0
                let g = Float(buffer[pixelIndex + 1]) / 255.0
                let r = Float(buffer[pixelIndex + 2]) / 255.0

                // MLMultiArray indexing: [batch, channel, height, width]
                let rIndex = [0, 0, y, x] as [NSNumber]
                let gIndex = [0, 1, y, x] as [NSNumber]
                let bIndex = [0, 2, y, x] as [NSNumber]

                mlArray[rIndex] = NSNumber(value: r)
                mlArray[gIndex] = NSNumber(value: g)
                mlArray[bIndex] = NSNumber(value: b)
            }
        }

        return mlArray
    }
}
