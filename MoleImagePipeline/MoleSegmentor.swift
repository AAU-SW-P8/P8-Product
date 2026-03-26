//
//  MoleSegmentor.swift
//  P8-Product
//
//  Created by Simon Thordal on 3/16/26.
//
import CoreML
import UIKit

class MoleSegmentor {
    // Edge-SAM uses two models: encoder processes the image, decoder generates masks from prompts
    
    private let encoder: edge_sam_encoder
    private let decoder: edge_sam_decoder
    // CIContext is expensive to create; stored as a field so it's reused across calls
    private let ciContext = CIContext()
    
    // Cache the image embeddings so we don't re-encode for multiple clicks on the same image
    private var cachedImageEmbeddings: MLMultiArray?
    private var cachedImageHash: Int?

    // `throws` means this initializer can fail — callers must use `try` and handle errors
    init() async throws {
        // Load the Edge-SAM encoder model
        guard let encoderURL = Bundle.main.url(forResource: "edge_sam_encoder", withExtension: "mlmodelc")
            ?? Bundle.main.url(forResource: "edge_sam_encoder", withExtension: "mlmodel") else {
            throw PipelineError.modelNotFound(name: "edge_sam_encoder")
        }
        
        // Load the Edge-SAM decoder model
        guard let decoderURL = Bundle.main.url(forResource: "edge_sam_decoder", withExtension: "mlmodelc")
            ?? Bundle.main.url(forResource: "edge_sam_decoder", withExtension: "mlmodel") else {
            throw PipelineError.modelNotFound(name: "edge_sam_decoder")
        }
        
        self.encoder = try await edge_sam_encoder.load(contentsOf: encoderURL)
        self.decoder = try await edge_sam_decoder.load(contentsOf: decoderURL)
    }

    /**
     Encodes the full image to create embeddings. This only needs to be done once per image.
     - Parameters:
        - image: The full image containing the mole
        - modelSize: The input size for the encoder (typically 1024x1024 for SAM)
     
     - Returns: Image embeddings that can be reused for multiple point prompts
     - Throws: invalidImage & renderFailed
     */
    private func encodeImage(_ image: UIImage, modelSize: Int = 1024) async throws -> MLMultiArray {
        // Check if we already have embeddings for this exact image
        let imageHash = image.hashValue
        if let cached = cachedImageEmbeddings, cachedImageHash == imageHash {
            return cached
        }
        
        guard let cgImage = image.cgImage else {
            throw PipelineError.invalidImage
        }
        
        let pixelBuffer = try createPixelBuffer(from: cgImage, size: modelSize)
        
        // Convert pixel buffer to MLMultiArray in the format the model expects: [1, 3, 1024, 1024]
        let mlArray = try convertPixelBufferToMLMultiArray(pixelBuffer, width: modelSize, height: modelSize)
        
        // Run the encoder
        let input = edge_sam_encoderInput(image: mlArray)
        let output = try await encoder.prediction(input: input)
        
        // Cache the embeddings
        cachedImageEmbeddings = output.image_embeddings
        cachedImageHash = imageHash
        
        return output.image_embeddings
    }
    
    /**
     Runs segmentation on an image based on a point click
     - Parameters:
        - image: The full image containing the mole
        - point: The CGPoint where the user clicked (in image coordinates)
        - modelSize: The input size for the SAM model (typically 1024x1024)
     
     - Returns: A segmentation mask showing the mole at the clicked location
     - Throws: invalidImage & renderFailed
     */
    func segment(image: UIImage, point: CGPoint, modelSize: Int = 1024) async throws -> MLMultiArray {
        // First, get the image embeddings
        let embeddings = try await encodeImage(image, modelSize: modelSize)
        
        // Normalize the point coordinates to the model's input size
        guard let cgImage = image.cgImage else {
            throw PipelineError.invalidImage
        }
        
        let scaleX = Double(modelSize) / Double(cgImage.width)
        let scaleY = Double(modelSize) / Double(cgImage.height)
        let normalizedX = Double(point.x) * scaleX
        let normalizedY = Double(point.y) * scaleY
        
        // Create point coordinates array [1, 1, 2] - format: [batch, num_points, coordinates]
        // Edge-SAM expects points in shape [1, num_points, 2]
        guard let pointCoords = try? MLMultiArray(shape: [1, 1, 2], dataType: .float32) else {
            throw PipelineError.renderFailed
        }
        pointCoords[[0, 0, 0] as [NSNumber]] = NSNumber(value: normalizedX)
        pointCoords[[0, 0, 1] as [NSNumber]] = NSNumber(value: normalizedY)
        
        // Create point labels array [1, 1] - format: [batch, num_points]
        // 1 means foreground point, 0 means background
        guard let pointLabels = try? MLMultiArray(shape: [1, 1], dataType: .float32) else {
            throw PipelineError.renderFailed
        }
        pointLabels[[0, 0] as [NSNumber]] = 1.0 // Foreground point
        
        // Run the decoder
        let decoderInput = edge_sam_decoderInput(
            image_embeddings: embeddings,
            point_coords: pointCoords,
            point_labels: pointLabels
        )
        let output = try await decoder.prediction(input: decoderInput)
        
        return output.masks
    }
    
    /**
     Helper method to create a CVPixelBuffer from a CGImage
     */
    private func createPixelBuffer(from cgImage: CGImage, size: Int) throws -> CVPixelBuffer {
        let originalCI = CIImage(cgImage: cgImage)
        let scaleX = CGFloat(size) / originalCI.extent.width
        let scaleY = CGFloat(size) / originalCI.extent.height
        let resizedCI = originalCI.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        
        let bufferAttributes: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        
        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(
            kCFAllocatorDefault,
            size,
            size,
            kCVPixelFormatType_32BGRA,
            bufferAttributes as CFDictionary,
            &pixelBuffer
        )
        
        guard let buffer = pixelBuffer else {
            throw PipelineError.renderFailed
        }
        
        ciContext.render(resizedCI, to: buffer)
        return buffer
    }
    
    /**
     Converts a CVPixelBuffer to MLMultiArray in the format [1, 3, height, width]
     The pixel values are normalized to [0, 1] range
     */
    private func convertPixelBufferToMLMultiArray(_ pixelBuffer: CVPixelBuffer, width: Int, height: Int) throws -> MLMultiArray {
        // Create MLMultiArray with shape [1, 3, height, width]
        guard let mlArray = try? MLMultiArray(shape: [1, 3, height as NSNumber, width as NSNumber], dataType: .float32) else {
            throw PipelineError.renderFailed
        }
        
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            throw PipelineError.renderFailed
        }
        
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)
        
        // Convert BGRA to RGB and normalize to [0, 1]
        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = y * bytesPerRow + x * 4
                
                let b = Float(buffer[pixelIndex]) / 255.0
                let g = Float(buffer[pixelIndex + 1]) / 255.0
                let r = Float(buffer[pixelIndex + 2]) / 255.0
                
                // MLMultiArray indexing: [batch, channel, height, width]
                let rIndex = [0, 0, y, x] as [NSNumber]
                let gIndex = [0, 1, y, x] as [NSNumber]
                let bIndex = [0, 2, y, x] as [NSNumber]
                
                mlArray[rIndex] = NSNumber(value: r)
                mlArray[gIndex] = NSNumber(value: g)
                mlArray[bIndex] = NSNumber(value: b)
            }
        }
        
        return mlArray
    }
    
    /// Clears the cached embeddings - call this when switching to a new image
    func clearCache() {
        cachedImageEmbeddings = nil
        cachedImageHash = nil
    }
}
