//
//  MoleDetector.swift
//  P8-Product
//
//  Created by Simon Thordal on 3/16/26.
//
import CoreML
import UIKit
import Vision


/// Custom error Enum containing error messages for this pipline
enum PipelineError: Error, LocalizedError {
    case modelNotFound(name: String)
    case invalidImage
    case renderFailed
    case unexpectedModelOutput


    var errorDiscripition: String {
        switch self {
        case .modelNotFound(name: let name): return "Model \(name) not found"
        case .invalidImage: return "Invalid Image"
        case .renderFailed: return "Failed to render image into pixel buffer"
        case .unexpectedModelOutput: return "Model output did not contain expected 'Identity' feature"
        }
    }
}

/// Pipnline Manager
class MolePipline {
    private let detector: MoleDetecor
    private let segmentor: MoleSegmentor
    
    
    init(detectorName: String, segmentorName: String) async throws {
        self.detector = try MoleDetecor(modelname: detectorName)
        self.segmentor = try await MoleSegmentor(modelname: segmentorName)
    }
}
