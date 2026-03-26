//
//  MoleDetector.swift
//  P8-Product
//
//
import CoreML
import UIKit
import Vision

/// Pipeline Manager
class MolePipeline {
    private let detector: MoleDetecor
    private let segmentor: MoleSegmentor
    
    
    init(detectorName: String) async throws {
        self.detector = try MoleDetecor(modelname: detectorName)
        self.segmentor = try await MoleSegmentor()
    }
}
