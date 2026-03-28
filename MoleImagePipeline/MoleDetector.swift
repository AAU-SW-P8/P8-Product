//
//  MoleDetecor.swift
//  P8-Product
//
//  Created by Simon Thordal on 3/16/26.
//

import Vision
import CoreML
import UIKit

class MoleDetector {
    // Makes bounding box around moles in a picture
    private let model: VNCoreMLModel
    
    init (modelname: String) throws {
        guard let modelURL = Bundle.main.url(forResource: modelname, withExtension: "mlmodelc")
        ?? Bundle.main.url(forResource: modelname, withExtension: "mlmodel") else {
            throw PipelineError.modelNotFound(name: modelname)
        }
        let coreMLmodel = try MLModel(contentsOf: modelURL)
        self.model = try VNCoreMLModel(for: coreMLmodel)
    }
}
