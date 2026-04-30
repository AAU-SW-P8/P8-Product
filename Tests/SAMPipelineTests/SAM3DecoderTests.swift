import CoreML
import Testing

@testable import P8_Product

/// Tests for `SAM3DecoderOutput`, verifying that the detection count is read correctly from the scores tensor shape.
@Suite("SAM3DecoderOutput")
struct SAM3DecoderOutputTests {

  /// Tests that the detection count correctly reads from the scores tensor shape.
  @Test func detectionCount_readsFromScoresShape() throws {
    let output = try makeMockDecoderOutput(
      scores: [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7],
      boxes: Array(repeating: Float(0), count: 7 * 4)
    )
    #expect(output.detectionCount == 7)
  }

  /// Tests that the detection count correctly reads from a single detection.
  @Test func detectionCount_singleDetection() throws {
    let output = try makeMockDecoderOutput(
      scores: [0.5],
      boxes: [0.5, 0.5, 0.2, 0.2]
    )
    #expect(output.detectionCount == 1)
  }
}
