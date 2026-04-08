//
//  SAM3Decoder.swift
//  P8-Product
//
//  Wraps the SAM 3.1 grounded mask decoder. Responsible for assembling the
//  decoder input dictionary from upstream features, running inference, and
//  validating the shapes of the returned tensors so that downstream code can
//  index into them without re-checking.
//

import CoreML

/// Typed view onto the decoder's three output tensors.
struct SAM3DecoderOutput {
    /// Per-detection mask logits, shape `[1, N, 288, 288]`.
    let masks: MLMultiArray
    /// Per-detection confidence scores in `[0, 1]`, shape `[1, N]`.
    let scores: MLMultiArray
    /// Per-detection bounding boxes in DETR `cx, cy, w, h` form, normalized
    /// to `[0, 1]`. Shape `[1, N, 4]`.
    let boxes: MLMultiArray

    /// Number of candidate detections produced by the decoder for this image.
    var detectionCount: Int { scores.shape[1].intValue }
}

/// Runs the SAM 3.1 grounded mask decoder.
final class SAM3Decoder {
    private let model: MLModel

    init(model: MLModel) {
        self.model = model
    }

    /// Runs the decoder against the given vision and text features.
    ///
    /// - Throws: `PipelineError.unexpectedModelOutput` if any expected feature
    ///   is missing or the returned tensors don't have the expected shapes.
    func run(visionFeatures: MLFeatureProvider, textFeatures: MLFeatureProvider) throws -> SAM3DecoderOutput {
        let input = try buildInput(visionFeatures: visionFeatures, textFeatures: textFeatures)

        print("🧠 Running decoder…")
        let output = try model.prediction(from: input)

        guard let masks  = output.featureValue(for: SAM3FeatureNames.Decoder.masks)?.multiArrayValue,
              let scores = output.featureValue(for: SAM3FeatureNames.Decoder.scores)?.multiArrayValue,
              let boxes  = output.featureValue(for: SAM3FeatureNames.Decoder.boxes)?.multiArrayValue else {
            print("❌ Decoder missing expected output features")
            print("   Available features: \(output.featureNames.joined(separator: ", "))")
            throw PipelineError.unexpectedModelOutput
        }

        print("📊 Scores shape: \(scores.shape), Boxes shape: \(boxes.shape), Masks shape: \(masks.shape)")
        try validateShapes(scores: scores, boxes: boxes, masks: masks)

        return SAM3DecoderOutput(masks: masks, scores: scores, boxes: boxes)
    }

    /// Pulls the FPN features + positional encoding out of the vision encoder
    /// output and the grounding tensors out of the text encoder output, then
    /// packs them into a single dictionary feature provider for the decoder.
    private func buildInput(visionFeatures: MLFeatureProvider, textFeatures: MLFeatureProvider) throws -> MLDictionaryFeatureProvider {
        guard let fpnFeat0 = visionFeatures.featureValue(for: SAM3FeatureNames.VisionEncoder.fpnFeat0),
              let fpnFeat1 = visionFeatures.featureValue(for: SAM3FeatureNames.VisionEncoder.fpnFeat1),
              let fpnFeat2 = visionFeatures.featureValue(for: SAM3FeatureNames.VisionEncoder.fpnFeat2),
              let visPos   = visionFeatures.featureValue(for: SAM3FeatureNames.VisionEncoder.visPos) else {
            print("❌ Vision encoder missing expected output features")
            print("   Available features: \(visionFeatures.featureNames.joined(separator: ", "))")
            throw PipelineError.unexpectedModelOutput
        }

        guard let textFeat = textFeatures.featureValue(for: SAM3FeatureNames.TextEncoder.features),
              let textMask = textFeatures.featureValue(for: SAM3FeatureNames.TextEncoder.mask) else {
            print("❌ Text encoder missing expected output features")
            throw PipelineError.unexpectedModelOutput
        }

        return try MLDictionaryFeatureProvider(dictionary: [
            SAM3FeatureNames.Decoder.fpnFeat0Input: fpnFeat0,
            SAM3FeatureNames.Decoder.fpnFeat1Input: fpnFeat1,
            SAM3FeatureNames.Decoder.fpnFeat2Input: fpnFeat2,
            SAM3FeatureNames.Decoder.visPosInput:   visPos,
            SAM3FeatureNames.Decoder.textFeatInput: textFeat,
            SAM3FeatureNames.Decoder.textMaskInput: textMask
        ])
    }

    /// Asserts that the decoder returned the tensor shapes downstream code
    /// expects: `scores [1,N]`, `boxes [1,N,4]`, `masks [1,N,H,W]` with `N`
    /// consistent across all three.
    private func validateShapes(scores: MLMultiArray, boxes: MLMultiArray, masks: MLMultiArray) throws {
        guard scores.shape.count == 2,
              boxes.shape.count == 3,
              masks.shape.count == 4,
              scores.shape[0] == 1,
              boxes.shape[0] == 1,
              masks.shape[0] == 1,
              scores.shape[1] == boxes.shape[1],
              scores.shape[1] == masks.shape[1],
              boxes.shape[2] == 4 else {
            print("❌ Unexpected output shapes from decoder")
            throw PipelineError.unexpectedModelOutput
        }
    }
}
