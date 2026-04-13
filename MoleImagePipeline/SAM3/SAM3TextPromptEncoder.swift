//
//  SAM3TextPromptEncoder.swift
//  P8-Product
//
//  Tokenizes the (currently fixed) text prompt "moles" with the CLIP
//  vocabulary and runs it through the SAM 3.1 text encoder. The output is
//  cached for the lifetime of the encoder because the prompt never changes.
//

import CoreML
import Foundation

/// Pre-encodes the fixed text prompt that drives grounded mole detection.
///
/// SAM 3.1 uses a CLIP tokenizer with a fixed sequence length of 32 tokens.
/// The prompt itself only needs three: `<|startoftext|>`, `"moles"`, and
/// `<|endoftext|>`. Remaining slots are filled with padding tokens.
final class SAM3TextPromptEncoder {

    // CLIP tokenizer vocabulary IDs.
    private static let startOfTextToken: Int32 = 49406  // <|startoftext|>
    private static let molesToken:       Int32 = 23529  // "moles"
    private static let endOfTextToken:   Int32 = 49407  // <|endoftext|>
    private static let paddingToken:     Int32 = 0
    private static let sequenceLength: Int = 32

    /// The pre-computed text encoder output, ready to be passed to the decoder.
    let features: MLFeatureProvider

    /// Tokenizes "moles" and runs the text encoder once. Throws if the encoder
    /// rejects the input or if the output cannot be constructed.
    init(encoder: MLModel) throws {
        let promptTokens: [Int32] = [Self.startOfTextToken, Self.molesToken, Self.endOfTextToken]
        let paddingCount: Int = Self.sequenceLength - promptTokens.count
        let tokenIds: [Int32] = promptTokens + Array(repeating: Self.paddingToken, count: paddingCount)

        let inputIds: MLMultiArray = try MLMultiArray(shape: [1, NSNumber(value: Self.sequenceLength)], dataType: .int32)
        for i: Int in 0..<Self.sequenceLength {
            inputIds[[0, i] as [NSNumber]] = NSNumber(value: tokenIds[i])
        }

        let input: MLDictionaryFeatureProvider = try MLDictionaryFeatureProvider(dictionary: [
            SAM3FeatureNames.TextEncoder.tokenIdsInput: MLFeatureValue(multiArray: inputIds)
        ])

        print("📝 Encoding text prompt 'moles'…")
        let output: MLFeatureProvider = try encoder.prediction(from: input)
        print("📝 Text encoder output features: \(output.featureNames.joined(separator: ", "))")
        self.features = output
    }
}
