//
//  SAM3FeatureNames.swift
//  P8-Product
//
//  Centralized constants for the brittle MLModel feature-name strings used by
//  the three SAM 3.1 sub-models. These names come from the converted CoreML
//  graph and would silently break inference if mistyped, so they live in one
//  place where they can be cross-referenced against the model card.
//

import Foundation

/// String identifiers for inputs/outputs of the SAM 3.1 CoreML models.
///
/// These names mirror the tensor names in the converted `.mlpackage` graphs.
/// If a model is re-exported, only this file needs to change.
enum SAM3FeatureNames {

    /// Outputs of the vision encoder. The FPN features are multi-scale image
    /// embeddings; `visPos` is a positional encoding consumed by the decoder.
    enum VisionEncoder {
        /// FPN feature map at full resolution — shape `[1, 256, 288, 288]`.
        static let fpnFeat0 = "x_495"
        /// FPN feature map at half resolution — shape `[1, 256, 144, 144]`.
        static let fpnFeat1 = "x_497"
        /// FPN feature map at quarter resolution — shape `[1, 256, 72, 72]`.
        static let fpnFeat2 = "x_499"
        /// Positional encoding fed into the decoder — shape `[1, 256, 72, 72]`.
        static let visPos   = "const_762"
        /// Input image tensor name — shape `[1, 3, 1008, 1008]`, Float16.
        static let imageInput = "image"
    }

    /// Outputs of the CLIP-style text encoder used for grounding.
    enum TextEncoder {
        /// Token-level text embeddings.
        static let features = "var_2489"
        /// Attention mask for the text tokens.
        static let mask     = "var_5"
        /// Input token-id tensor name.
        static let tokenIdsInput = "token_ids"
    }

    /// Outputs of the grounded mask decoder.
    enum Decoder {
        /// Per-detection mask logits — shape `[1, N, 288, 288]`.
        static let masks  = "var_5020"
        /// Per-detection confidence scores — shape `[1, N]`.
        static let scores = "var_4806"
        /// Per-detection bounding boxes in DETR `cx,cy,w,h` normalized form
        /// — shape `[1, N, 4]`.
        static let boxes  = "var_4734"

        // Decoder input keys.
        static let fpnFeat0Input = "fpn_feat0"
        static let fpnFeat1Input = "fpn_feat1"
        static let fpnFeat2Input = "fpn_feat2"
        static let visPosInput   = "vis_pos"
        static let textFeatInput = "text_features"
        static let textMaskInput = "text_mask"
    }
}
