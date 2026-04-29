//
//  PipelineError.swift
//  P8-Product
//
//  Created by Simon Thordal on 3/24/26.
//

import Foundation

enum PipelineError: LocalizedError {
    case modelNotFound(name: String)
    case invalidImage
    case renderFailed
    case unexpectedModelOutput

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
