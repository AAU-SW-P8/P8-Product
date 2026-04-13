//
//  SAM3Models.swift
//  P8-Product
//
//  Loads the three CoreML models that make up SAM 3.1: the vision encoder,
//  the text encoder, and the grounded mask decoder. Loading is split out so
//  that `MoleSegmentor` only has to ask for a ready-to-use bundle.
//

import CoreML
import Foundation

/// A loaded triple of SAM 3.1 CoreML models.
///
/// The vision encoder runs on `cpuAndGPU` to avoid Apple Neural Engine
/// compilation failures and multi-minute compile hangs observed on low-RAM
/// devices (e.g. iPhone 12 mini, 4 GB). The text encoder and decoder are
/// allowed to use any compute unit because they are small and well-behaved.
struct SAM3Models {
    let visionEncoder: MLModel
    let textEncoder: MLModel
    let decoder: MLModel

    /// Loads all three SAM 3.1 models from the app bundle.
    ///
    /// - Throws: `PipelineError.modelNotFound` if any of the three model
    ///   resources are missing from the bundle.
    static func load() async throws -> SAM3Models {
        let visionConfig: MLModelConfiguration = MLModelConfiguration()
        // .cpuAndGPU avoids ANECCompile failures and minute-long ANE compile
        // hangs that bite low-RAM devices on the large image encoder.
        visionConfig.computeUnits = .cpuAndGPU

        let defaultConfig: MLModelConfiguration = MLModelConfiguration()
        defaultConfig.computeUnits = .all

        print("Loading SAM3 vision encoder…")
        let vision: MLModel = try await loadModel(named: "SAM3.1_ImageEncoder_FP16", configuration: visionConfig)
        print("Loading SAM3 text encoder…")
        let text: MLModel = try await loadModel(named: "SAM3.1_TextEncoder_FP16", configuration: defaultConfig)
        print("Loading SAM3 decoder…")
        let decoder: MLModel = try await loadModel(named: "SAM3.1_Detector_FP16", configuration: defaultConfig)

        return SAM3Models(visionEncoder: vision, textEncoder: text, decoder: decoder)
    }

    /// Resolves a CoreML model URL from the app bundle, preferring the
    /// compiled `.mlmodelc` form and falling back to `.mlpackage`.
    private static func loadModel(named name: String, configuration: MLModelConfiguration) async throws -> MLModel {
        guard let url: URL = Bundle.main.url(forResource: name, withExtension: "mlmodelc")
            ?? Bundle.main.url(forResource: name, withExtension: "mlpackage") else {
            throw PipelineError.modelNotFound(name: name)
        }
        return try await MLModel.load(contentsOf: url, configuration: configuration)
    }
}
