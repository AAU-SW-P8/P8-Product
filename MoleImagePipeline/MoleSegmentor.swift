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
///   2. **Text encoder** — turns the prompt `"mole"` into a text embedding
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

    /// Loads the three SAM 3.1 models from the app bundle and pre-encodes the fixed `"mole"` text prompt.
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

    /// Segments moles in the given image using the prompt `"mole"`.
    ///
    /// - Parameters:
    ///   - image: The full-resolution photo to segment.
    ///   - confidenceThreshold: Minimum decoder probability for a detection to be kept. Defaults to `0.3`.
    ///   - nmsThreshold: IoU threshold above which overlapping detections are suppressed. The default of `1.0` effectively disables NMS;
    ///     pass ~`0.5` for actual deduplication.
    /// - Returns: A tuple of (annotated overlay image, bounding boxes in pixel
    ///   coordinates, mask-only image for area calculation), or `nil` if no
    ///   detections passed the confidence threshold or if overlay or mask-only  
    ///   rendering fails. 
    func segment(image: UIImage, confidenceThreshold: Float = 0.3, nmsThreshold: Float = 1.0) throws -> (UIImage, [CGRect], UIImage)? {
        let clock = ContinuousClock()

        // Normalize orientation so that cgImage pixels match the visual orientation.
        // Camera photos often have .imageOrientation = .right, which means the raw
        // cgImage is rotated 90° relative to what UIImage.draw renders. Flattening
        // here ensures the preprocessor, model, and renderer all see the same layout.
        let image = image.normalizedOrientation()

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
        guard let (overlay, boxes) = renderer.renderOverlay(on: image, detections: detections, masks: decoderOutput.masks) else {
            return nil
        }

        // 6. Build a mask-only image for area calculation (alpha encodes mole pixels).
        guard let maskOnly = renderer.renderMaskOnly(imageSize: image.size, detections: detections, masks: decoderOutput.masks) else {
            return nil
        }

        return (overlay, boxes, maskOnly)
    }

    /// Drops the cached vision embeddings. Call this whenever the displayed
    /// image changes so the next `segment(_:)` call re-encodes from scratch.
    func clearCache() {
        visionEncoder.clearCache()
    }
}
