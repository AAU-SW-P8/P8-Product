//
//  SAM3Detection.swift
//  P8-Product
//
//  Pure post-processing helpers that turn the decoder's raw tensors into a
//  filtered, deduplicated list of mole detections. Kept side-effect free so
//  the math (confidence filtering, IoU, NMS) can be unit tested without
//  loading any CoreML models.
//

import CoreGraphics
import CoreML
import Foundation

/// One candidate detection produced by the decoder.
struct RawDetection {
    /// Index of this detection within the decoder output tensors.
    let index: Int
    /// Confidence score in `[0, 1]`.
    let prob: Float
    /// Bounding box in normalized `[0, 1]` image coordinates (top-left origin).
    let box: CGRect
}

/// Functions for filtering and deduplicating decoder output. All `static`
/// because none of them need state — easier to test, easier to reason about.
enum SAM3Detection {

    /// Returns every detection whose score is at least `threshold`.
    ///
    /// - Parameters:
    ///   - output: Decoder result, validated to have shapes `[1,N]`, `[1,N,4]`,
    ///     `[1,N,288,288]`.
    ///   - threshold: Minimum probability in `[0, 1]`.
    static func filterByConfidence(_ output: SAM3DecoderOutput, threshold: Float) -> [RawDetection] {
        var detections: [RawDetection] = []
        for i in 0..<output.detectionCount {
            let prob: Float = output.scores[[0, i] as [NSNumber]].floatValue
            guard prob >= threshold else { continue }

            // DETR-style cx,cy,w,h normalized to [0,1].
            let cx: CGFloat = CGFloat(output.boxes[[0, i, 0] as [NSNumber]].floatValue)
            let cy: CGFloat = CGFloat(output.boxes[[0, i, 1] as [NSNumber]].floatValue)
            let w: CGFloat  = CGFloat(output.boxes[[0, i, 2] as [NSNumber]].floatValue)
            let h: CGFloat  = CGFloat(output.boxes[[0, i, 3] as [NSNumber]].floatValue)
            let box: CGRect = CGRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h)
            detections.append(RawDetection(index: i, prob: prob, box: box))
        }
        return detections
    }

    /// Greedy non-maximum suppression. Detections are kept in descending
    /// confidence order; any detection whose IoU with an already-kept box
    /// exceeds `iouThreshold` is dropped.
    ///
    /// - Note: An `iouThreshold` of `1.0` is effectively a no-op (IoU never
    ///   strictly exceeds 1), which matches the historical default in this
    ///   pipeline. Use `~0.5` if you want actual deduplication.
    static func nonMaxSuppression(_ detections: [RawDetection], iouThreshold: Float) -> [RawDetection] {
        let sorted: [RawDetection] = detections.sorted { $0.prob > $1.prob }
        var kept: [RawDetection] = []
        for det: RawDetection in sorted {
            let dominated: Bool = kept.contains { intersectionOverUnion($0.box, det.box) > iouThreshold }
            if !dominated { kept.append(det) }
        }
        return kept
    }

    /// Standard Intersection-over-Union of two axis-aligned rectangles.
    /// Returns `0` for disjoint rectangles or degenerate (zero-area) inputs.
    static func intersectionOverUnion(_ a: CGRect, _ b: CGRect) -> Float {
        let intersection: CGRect = a.intersection(b)
        if intersection.isNull { return 0 }
        let interArea: Float = Float(intersection.width * intersection.height)
        let unionArea: Float = Float(a.width * a.height + b.width * b.height) - interArea
        return unionArea > 0 ? interArea / unionArea : 0
    }
}
