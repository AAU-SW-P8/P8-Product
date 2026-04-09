import Testing
@testable import P8_Product

// SAM3TextPromptEncoder requires a real CoreML MLModel to initialize because
// its init immediately runs encoder.prediction(from:). The tokenization logic
// (building the CLIP token array) is embedded inside init and cannot be tested
// in isolation without refactoring the production code.
//
// To make this testable, the tokenization step could be extracted into a
// static method that returns the MLMultiArray of token IDs. That would allow
// verifying:
//   - Token sequence is [49406, 23529, 49407, 0, 0, ..., 0] (length 32)
//   - Shape is [1, 32], dataType is .int32

@Suite("SAM3TextPromptEncoder")
struct SAM3TextPromptEncoderTests {
    // No tests can run without a real model. See comment above.
}
