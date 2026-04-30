import Testing

@testable import P8_Product

/// Tests for `SAM3FeatureNames`, verifying that all model I/O feature name constants are non-empty and unique.
@Suite("SAM3FeatureNames")
struct SAM3FeatureNamesTests {

  /// Tests that vision encoder constants are non-empty and unique.
  @Test func visionEncoder_constantsAreNonEmptyAndUnique() {
    let values = [
      SAM3FeatureNames.VisionEncoder.fpnFeat0,
      SAM3FeatureNames.VisionEncoder.fpnFeat1,
      SAM3FeatureNames.VisionEncoder.fpnFeat2,
      SAM3FeatureNames.VisionEncoder.visPos,
      SAM3FeatureNames.VisionEncoder.imageInput,
    ]
    for v in values { #expect(!v.isEmpty) }
    #expect(Set(values).count == values.count, "Duplicate feature names detected")
  }

  /// Tests that text encoder constants are non-empty and unique.
  @Test func textEncoder_constantsAreNonEmptyAndUnique() {
    let values = [
      SAM3FeatureNames.TextEncoder.features,
      SAM3FeatureNames.TextEncoder.mask,
      SAM3FeatureNames.TextEncoder.tokenIdsInput,
    ]
    for v in values { #expect(!v.isEmpty) }
    #expect(Set(values).count == values.count, "Duplicate feature names detected")
  }

  /// Tests that decoder constants are non-empty and unique.
  @Test func decoder_constantsAreNonEmptyAndUnique() {
    let values = [
      SAM3FeatureNames.Decoder.masks,
      SAM3FeatureNames.Decoder.scores,
      SAM3FeatureNames.Decoder.boxes,
      SAM3FeatureNames.Decoder.fpnFeat0Input,
      SAM3FeatureNames.Decoder.fpnFeat1Input,
      SAM3FeatureNames.Decoder.fpnFeat2Input,
      SAM3FeatureNames.Decoder.visPosInput,
      SAM3FeatureNames.Decoder.textFeatInput,
      SAM3FeatureNames.Decoder.textMaskInput,
    ]
    for v in values { #expect(!v.isEmpty) }
    #expect(Set(values).count == values.count, "Duplicate feature names detected")
  }
}
