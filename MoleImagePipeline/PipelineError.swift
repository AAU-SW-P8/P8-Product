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
            return String(format: NSLocalizedString("pipeline.error.modelNotFound.format", tableName: "Localizable", bundle: .main, value: "Could not find model: %@", comment: "Model not found error with name placeholder"), name)
        case .invalidImage:
            return NSLocalizedString("pipeline.error.invalidImage", tableName: "Localizable", bundle: .main, value: "Invalid image - could not convert to CGImage", comment: "Invalid image error" )
        case .renderFailed:
            return NSLocalizedString("pipeline.error.renderFailed", tableName: "Localizable", bundle: .main, value: "Failed to render or process image data", comment: "Render failed error" )
        case .unexpectedModelOutput:
            return NSLocalizedString("pipeline.error.unexpectedModelOutput", tableName: "Localizable", bundle: .main, value: "Model output did not contain expected 'Identity' feature", comment: "Unexpected model output error" )
        }
    }
}
