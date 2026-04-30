import CoreML
import Foundation

@testable import P8_Product

/// Creates a SAM3DecoderOutput with known values for testing.
///
/// - Parameters:
///   - scores: Array of n Float values (one per detection).
///   - boxes: Array of n*4 Float values in cx, cy, w, h order.
///   - maskH: Height of the mask tensor (default 2 to save memory).
///   - maskW: Width of the mask tensor (default 2 to save memory).
func makeMockDecoderOutput(
  scores: [Float],
  boxes: [Float],
  maskH: Int = 2,
  maskW: Int = 2
) throws -> SAM3DecoderOutput {
  let n = scores.count
  precondition(boxes.count == n * 4, "boxes must have exactly n*4 elements")

  let scoreArray = try MLMultiArray(shape: [1, NSNumber(value: n)], dataType: .float32)
  for i in 0..<n {
    scoreArray[[0, i] as [NSNumber]] = NSNumber(value: scores[i])
  }

  let boxArray = try MLMultiArray(shape: [1, NSNumber(value: n), 4], dataType: .float32)
  for i in 0..<n {
    for j in 0..<4 {
      boxArray[[0, i, j] as [NSNumber]] = NSNumber(value: boxes[i * 4 + j])
    }
  }

  let maskArray = try MLMultiArray(
    shape: [1, NSNumber(value: n), NSNumber(value: maskH), NSNumber(value: maskW)],
    dataType: .float32
  )
  // Masks are left zero-filled; no tested logic reads them.

  return SAM3DecoderOutput(masks: maskArray, scores: scoreArray, boxes: boxArray)
}
