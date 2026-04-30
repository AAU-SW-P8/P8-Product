//
//  SAM3VisionEncoder.swift
//  P8-Product
//
//  Wraps the SAM 3.1 vision encoder model with a one-image cache so that
//  multiple segmentations on the same photo do not pay the encoding cost
//  twice.
//

import CoreML
import UIKit

/// Runs the SAM 3.1 vision encoder, caching its output per image.
final class SAM3VisionEncoder {
  /// The Core ML model.
  private let model: MLModel
  /// The image preprocessor.
  private let preprocessor: SAM3ImagePreprocessor

  /// The cached output from the vision encoder.
  private var cachedOutput: MLFeatureProvider?
  /// The hash of the image used to generate the cached output.
  private var cachedImageHash: Int?

  /// Initializes the encoder.
  init(model: MLModel, preprocessor: SAM3ImagePreprocessor) {
    self.model = model
    self.preprocessor = preprocessor
  }

  /// Encodes the given image, returning the cached output if the same image
  ///
  /// - Important: `UIImage.hashValue` is identity-based, so two distinct
  ///   `UIImage` instances loaded from the same source will not share a
  ///   cache entry. Call `clearCache()` whenever the displayed image changes.
  func encode(_ image: UIImage) throws -> MLFeatureProvider {
    let imageHash: Int = image.hashValue
    if let cached: MLFeatureProvider = cachedOutput, cachedImageHash == imageHash {
      print("Using cached vision embeddings")
      return cached
    }

    let imageTensor: MLMultiArray = try preprocessor.preprocess(image)
    let input: MLDictionaryFeatureProvider = try MLDictionaryFeatureProvider(dictionary: [
      SAM3FeatureNames.VisionEncoder.imageInput: MLFeatureValue(multiArray: imageTensor)
    ])

    let output: MLFeatureProvider = try model.prediction(from: input)
    print("Vision encoder output features: \(output.featureNames.joined(separator: ", "))")
    cachedOutput = output
    cachedImageHash = imageHash
    return output
  }

  /// Drops the cached embeddings. Call this whenever the source image changes.
  func clearCache() {
    cachedOutput = nil
    cachedImageHash = nil
  }
}
