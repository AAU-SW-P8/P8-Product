import CoreGraphics
import CoreML
import Testing

@testable import P8_Product

/// Tests for `SAM3Detection`, covering IoU calculation, NMS, and confidence-based filtering.
struct SAM3DetectionTests {

  // MARK: - Intersection Over Union

  /// Tests identical boxes return 1.0.
  @Test func iou_identicalBoxes_returnsOne() {
    let box = CGRect(x: 0, y: 0, width: 1, height: 1)
    let result = SAM3Detection.intersectionOverUnion(box, box)
    #expect(result == 1.0)
  }

  /// Tests disjoint boxes return 0.0.
  @Test func iou_disjointBoxes_returnsZero() {
    let a = CGRect(x: 0, y: 0, width: 1, height: 1)
    let b = CGRect(x: 2, y: 2, width: 1, height: 1)
    let result = SAM3Detection.intersectionOverUnion(a, b)
    #expect(result == 0.0)
  }

  /// Tests partial overlap returns correct value.
  @Test func iou_partialOverlap_returnsCorrectValue() {
    let a = CGRect(x: 0, y: 0, width: 2, height: 2)  // area = 4
    let b = CGRect(x: 1, y: 1, width: 2, height: 2)  // area = 4
    // intersection = (1,1,1,1), area = 1, union = 4+4-1 = 7
    let result = SAM3Detection.intersectionOverUnion(a, b)
    #expect(abs(result - 1.0 / 7.0) < 1e-5)
  }

  /// Tests zero area box returns 0.0.
  @Test func iou_zeroAreaBox_returnsZero() {
    let a = CGRect(x: 0, y: 0, width: 0, height: 0)
    let b = CGRect(x: 0, y: 0, width: 1, height: 1)
    let result = SAM3Detection.intersectionOverUnion(a, b)
    #expect(result == 0.0)
  }

  /// Tests contained box returns correct value.
  @Test func iou_containedBox_returnsCorrectValue() {
    let outer = CGRect(x: 0, y: 0, width: 4, height: 4)  // area = 16
    let inner = CGRect(x: 1, y: 1, width: 2, height: 2)  // area = 4
    // intersection area = 4, union = 16+4-4 = 16
    let result = SAM3Detection.intersectionOverUnion(outer, inner)
    #expect(abs(result - 0.25) < 1e-5)
  }

  // MARK: - Non-Maximum Suppression

  /// Tests empty input returns empty.
  @Test func nms_emptyInput_returnsEmpty() {
    let result = SAM3Detection.nonMaxSuppression([], iouThreshold: 0.5)
    #expect(result.isEmpty)
  }

  /// Tests single detection is kept.
  @Test func nms_singleDetection_kept() {
    let det = RawDetection(index: 0, prob: 0.9, box: CGRect(x: 0, y: 0, width: 1, height: 1))
    let result = SAM3Detection.nonMaxSuppression([det], iouThreshold: 0.5)
    #expect(result.count == 1)
    #expect(result[0].index == 0)
  }

  /// Tests overlapping pair removes lower confidence.
  @Test func nms_overlappingPair_removesLowerConfidence() {
    let high = RawDetection(index: 0, prob: 0.9, box: CGRect(x: 0, y: 0, width: 1, height: 1))
    let low = RawDetection(index: 1, prob: 0.5, box: CGRect(x: 0, y: 0, width: 1, height: 1))
    let result = SAM3Detection.nonMaxSuppression([low, high], iouThreshold: 0.5)
    #expect(result.count == 1)
    #expect(result[0].index == 0)
  }

  /// Tests non-overlapping pair keeps both.
  @Test func nms_nonOverlappingPair_keepsBoth() {
    let a = RawDetection(index: 0, prob: 0.9, box: CGRect(x: 0, y: 0, width: 1, height: 1))
    let b = RawDetection(index: 1, prob: 0.5, box: CGRect(x: 5, y: 5, width: 1, height: 1))
    let result = SAM3Detection.nonMaxSuppression([a, b], iouThreshold: 0.5)
    #expect(result.count == 2)
  }

  /// Tests threshold one keeps all.
  @Test func nms_thresholdOne_keepsAll() {
    // IoU of identical boxes = 1.0, which is NOT > 1.0, so both are kept.
    let a = RawDetection(index: 0, prob: 0.9, box: CGRect(x: 0, y: 0, width: 1, height: 1))
    let b = RawDetection(index: 1, prob: 0.5, box: CGRect(x: 0, y: 0, width: 1, height: 1))
    let result = SAM3Detection.nonMaxSuppression([a, b], iouThreshold: 1.0)
    #expect(result.count == 2)
  }

  // MARK: - Filter By Confidence

  /// Tests below threshold is excluded.
  @Test func filterByConfidence_belowThreshold_excluded() throws {
    let output = try makeMockDecoderOutput(
      scores: [0.1, 0.6, 0.9],
      boxes: [
        0.5, 0.5, 0.2, 0.2,  // detection 0
        0.5, 0.5, 0.2, 0.2,  // detection 1
        0.5, 0.5, 0.2, 0.2,  // detection 2
      ]
    )
    let result = SAM3Detection.filterByConfidence(output, threshold: 0.5)
    #expect(result.count == 2)
    #expect(result[0].index == 1)
    #expect(result[1].index == 2)

    // Verify DETR cx,cy,w,h -> CGRect conversion: cx=0.5, cy=0.5, w=0.2, h=0.2
    // => x = 0.5-0.1=0.4, y = 0.5-0.1=0.4, width=0.2, height=0.2
    let box = result[0].box
    #expect(abs(box.origin.x - 0.4) < 1e-5)
    #expect(abs(box.origin.y - 0.4) < 1e-5)
    #expect(abs(box.width - 0.2) < 1e-5)
    #expect(abs(box.height - 0.2) < 1e-5)
  }

  /// Tests all below threshold returns empty.
  @Test func filterByConfidence_allBelowThreshold_returnsEmpty() throws {
    let output = try makeMockDecoderOutput(
      scores: [0.1, 0.2],
      boxes: [
        0.5, 0.5, 0.2, 0.2,
        0.5, 0.5, 0.2, 0.2,
      ]
    )
    let result = SAM3Detection.filterByConfidence(output, threshold: 0.5)
    #expect(result.isEmpty)
  }
}
