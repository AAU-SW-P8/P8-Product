//
//  PipelineError.swift
//  P8-Product
//

import Foundation

/// The `PipelineError` type.
enum PipelineError: LocalizedError {
  /// The `modelNotFound` case.
  case modelNotFound(name: String)
  /// The `invalidImage` case.
  case invalidImage
  /// The `renderFailed` case.
  case renderFailed
  /// The `unexpectedModelOutput` case.
  case unexpectedModelOutput

  /// The `errorDescription` property.
  var errorDescription: String? {
    switch self {
    case .modelNotFound(let name):
      return "Could not find model: \(name)"
    case .invalidImage:
      return "Invalid image - could not convert to CGImage"
    case .renderFailed:
      return "Failed to render or process image data"
    case .unexpectedModelOutput:
      return "Model output did not contain expected 'Identity' feature"
    }
  }
}
