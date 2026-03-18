//
//  MoleSegmentor.swift
//  P8-Product
//
//  Created by Simon Thordal on 3/16/26.
//
import CoreML
import UIKit

class MoleSegmentor {
    //takes single mole and makes a segmentation mask

    // `private let` — constant field, equivalent to a private final field in Java/C#
    private let model: unet_mole
    // CIContext is expensive to create; stored as a field so it's reused across calls
    private let ciContext = CIContext()

    // `throws` means this initializer can fail — callers must use `try` and handle errors
    init(modelname: String) async throws {
        // `guard let` is an early-exit unwrap: if the right-hand side is nil,
        // the else block runs and must exit the scope (here via throw).
        guard let modelURL = Bundle.main.url(forResource: modelname, withExtension: "mlmodelc")
            ?? Bundle.main.url(forResource: modelname, withExtension: "mlmodel") else {
            throw PipelineError.modelNotFound(name: modelname)
        }
        self.model = try await unet_mole.load(contentsOf: modelURL)
    }

    /**
     Runs segmentation on a cropped image
     - Parameters:
        - cropped: Image cropped specifically focused on a mole.
        - modelSize: The input UNet model

     
     - Returns: An MLMultiArray mask output from the UNet model. Size: [1, 256, 256, 3]
        - 1 is amount of images
        - 256 is the resolution
        - 3 is the color chanels
     
     - Throws: invalidImage & renderFailed.
     
     */
    func segment(cropped: UIImage, modelSize: Int = 256)
    async throws -> MLMultiArray? {
        // guard only runs this function if condition holds.
        // `.cgImage` is an optional property — UIImage wraps CGImage but doesn't always have one
        guard let cgImage = cropped.cgImage else {
            throw PipelineError.invalidImage
        }

        // CIImage is an immutable image representation used by Core Image (GPU-accelerated filters).
        // '.extent' is the image's bounding rectangle (origin + size)
        let originalCI = CIImage(cgImage: cgImage)
        let scaleX = CGFloat(modelSize) / originalCI.extent.width
        let scaleY = CGFloat(modelSize) / originalCI.extent.height
        // `.transformed(by:)` returns a new CIImage — CIImage operations are lazy/non-destructive
        let resizedCI = originalCI.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        // CVPixelBuffer is a raw pixel memory buffer used by CoreML and CoreImage.
        // The attributes tell the system this buffer needs to be compatible with CGImage rendering.
        let bufferAttributes: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        // CVPixelBufferCreate uses an output-parameter pattern: pass a pointer with '&' at the end
        // and the function writes the result into it. The result is Optional (nil on failure)
        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, modelSize, modelSize, kCVPixelFormatType_32BGRA, bufferAttributes as CFDictionary, &pixelBuffer)
        guard let inputBuffer = pixelBuffer else {
            throw PipelineError.renderFailed
        }
        // Renders the CIImage into the pixel buffer
        ciContext.render(resizedCI, to: inputBuffer)

        // unet_moleInput is a generated Swift wrapper for the CoreML model's input schema
        let input = unet_moleInput(x: inputBuffer)
        let output = try await model.prediction(input: input)

        // '?.' is optional chaining — if featureValue returns nil, the whole expression is nil
        // and the guard triggers. MLMultiArray is CoreML's n-dimensional array type (like numpy ndarray).

        return output.Identity
    }
}
