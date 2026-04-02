//
//  MolePipeline.swift
//  P8-Product
//
//
import CoreML
import UIKit
import Vision

/// Pipeline Manager
class MolePipeline {
    private let detector: MoleDetector
    private let segmentor: MoleSegmentor
    
    
    init(detectorName: String) async throws {
        self.detector = try MoleDetector(modelname: detectorName)
        self.segmentor = try await MoleSegmentor()
    }
}
