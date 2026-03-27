//
//  MoleSegmentor.swift
//  P8-Product
//
//  Created by Simon Thordal on 3/16/26.
//
import CoreML
import UIKit

class MoleSegmentor {

    // MARK: - Types

    enum PipelineError: Error {
        case modelNotFound(name: String)
        case invalidImage
        case renderFailed
    }

    // MARK: - Properties

    // SAM 2 uses three models: Image Encoder, Prompt Encoder, and Mask Decoder
    private let imageEncoder: SAM2_1LargeImageEncoderFLOAT16
    private let promptEncoder: SAM2_1LargePromptEncoderFLOAT16
    private let maskDecoder: SAM2_1LargeMaskDecoderFLOAT16

    private let ciContext = CIContext()

    // Cache the image encoder output (SAM 2 usually requires high-res features in addition to base embeddings)
    // We store the entire output object to easily pass its properties to the decoder later.
    private var cachedEncoderOutput: SAM2_1LargeImageEncoderFLOAT16Output?
    private var cachedImageHash: Int?

    // MARK: - Init

    init() async throws {
        // Load Image Encoder URL
        guard let encoderURL = Bundle.main.url(forResource: "SAM2_1LargeImageEncoderFLOAT16", withExtension: "mlmodelc")
            ?? Bundle.main.url(forResource: "SAM2_1LargeImageEncoderFLOAT16", withExtension: "mlmodel") else {
            throw PipelineError.modelNotFound(name: "SAM2_1LargeImageEncoderFLOAT16")
        }

        // Load Prompt Encoder URL
        guard let promptURL = Bundle.main.url(forResource: "SAM2_1LargePromptEncoderFLOAT16", withExtension: "mlmodelc")
            ?? Bundle.main.url(forResource: "SAM2_1LargePromptEncoderFLOAT16", withExtension: "mlmodel") else {
            throw PipelineError.modelNotFound(name: "SAM2_1LargePromptEncoderFLOAT16")
        }

        // Load Mask Decoder URL
        guard let decoderURL = Bundle.main.url(forResource: "SAM2_1LargeMaskDecoderFLOAT16", withExtension: "mlmodelc")
            ?? Bundle.main.url(forResource: "SAM2_1LargeMaskDecoderFLOAT16", withExtension: "mlmodel") else {
            throw PipelineError.modelNotFound(name: "SAM2_1LargeMaskDecoderFLOAT16")
        }

        // --- THE FIX ---
        // Create a configuration that forces Core ML to bypass the Apple Neural Engine
        let config = MLModelConfiguration()
            config.computeUnits = .cpuOnly

            // Initialize the models with the CPU-only configuration
            self.imageEncoder = try await SAM2_1LargeImageEncoderFLOAT16.load(contentsOf: encoderURL, configuration: config)
            self.promptEncoder = try await SAM2_1LargePromptEncoderFLOAT16.load(contentsOf: promptURL, configuration: config)
            self.maskDecoder = try await SAM2_1LargeMaskDecoderFLOAT16.load(contentsOf: decoderURL, configuration: config)
        }

    // MARK: - Public

    func segment(image: UIImage, point: CGPoint, modelSize: Int = 1024) async throws -> MLMultiArray {
        // 1. Get the Image Features (Embeddings + High Res features)
        let encoderOutput = try await encodeImage(image, modelSize: modelSize)

        // ADD THIS: Check if the image encoder actually saw anything
        print("📸 Image Encoder test value: \(encoderOutput.image_embedding[0])")

        guard let cgImage = image.cgImage else { throw PipelineError.invalidImage }

        let scaleX = Double(modelSize) / Double(cgImage.width)
        let scaleY = Double(modelSize) / Double(cgImage.height)
        let normalizedX = Double(point.x) * scaleX
        let normalizedY = Double(point.y) * scaleY

        // 2. Set up Prompt Encoder Inputs
        // Note: Check Xcode autocomplete to see if it wants .float32 or .float16 based on your model export
        guard let pointCoords = try? MLMultiArray(shape: [1, 2, 2], dataType: .float16),
              let pointLabels = try? MLMultiArray(shape: [1, 2], dataType: .float16) else {
            throw PipelineError.renderFailed
        }

        // POINT 1: The user's actual click
        pointCoords[[0, 0, 0] as [NSNumber]] = NSNumber(value: normalizedX)
        pointCoords[[0, 0, 1] as [NSNumber]] = NSNumber(value: normalizedY)
        pointLabels[[0, 0] as [NSNumber]] = 1.0 // 1.0 = Foreground

        // POINT 2: The SAM padding point
        // SAM requires this dummy point so the tensor is the correct size
        pointCoords[[0, 1, 0] as [NSNumber]] = 0.0
        pointCoords[[0, 1, 1] as [NSNumber]] = 0.0
        pointLabels[[0, 1] as [NSNumber]] = -1.0 // -1.0 = Ignore / Padding

        // Run Prompt Encoder
        let promptInput = SAM2_1LargePromptEncoderFLOAT16Input(
            points: pointCoords,
            labels: pointLabels
        )
        let promptOutput = try await promptEncoder.prediction(input: promptInput)

        // ADD THIS: Check if the prompt encoder actually registered the click
        print("🎯 Prompt Encoder test value: \(promptOutput.dense_embeddings[0])")

        // 3. Set up Mask Decoder Inputs
        // Combine image features and prompt features
        // NOTE: SAM 2 image encoders usually output `image_embeddings`, `high_res_feats_0`, and `high_res_feats_1`.
        // Ensure you are passing all required features to the decoder input.
        let decoderInput = SAM2_1LargeMaskDecoderFLOAT16Input(
            image_embedding: encoderOutput.image_embedding,
            sparse_embedding: promptOutput.sparse_embeddings, // Note: watch out for the 's' at the end of promptOutput.sparse_embeddings if the parameter name is singular!
            dense_embedding: promptOutput.dense_embeddings,
            feats_s0: encoderOutput.feats_s0,
            feats_s1: encoderOutput.feats_s1
        )

        let decoderOutput = try await maskDecoder.prediction(input: decoderInput)

        // Return the generated masks
        return decoderOutput.low_res_masks
    }

    /**
     Converts the SAM mask output into a transparent UIImage with a colored overlay.
     */
    func createMaskImage(from mlArray: MLMultiArray) -> UIImage? {
        let shape = mlArray.shape
        // SAM mask outputs usually have the shape [batch, masks, height, width].
        // We grab the height and width from the last two dimensions.
        let height = shape[shape.count - 2].intValue
        let width = shape[shape.count - 1].intValue

        // Create an array to hold the raw RGBA pixel data
        var pixels = [UInt8](repeating: 0, count: width * height * 4)

        // Safely get a pointer to the Float32 data inside the MLMultiArray
        // Note: If your decoder outputs Float16, you will need to cast this to Float16 instead
        guard let pointer = try? UnsafeBufferPointer<Float32>(mlArray) else {
            print("Failed to access MLMultiArray data")
            return nil
        }

        // Iterate through the pixels
        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                let value = pointer[index]

                let pixelIndex = index * 4

                // If logit > 0, it's the mole! Paint it semi-transparent red.
                if value > 0.0 {
                    pixels[pixelIndex]     = 255  // Red
                    pixels[pixelIndex + 1] = 0    // Green
                    pixels[pixelIndex + 2] = 0    // Blue
                    pixels[pixelIndex + 3] = 128  // Alpha (Semi-transparent)
                } else {
                    // Background is completely transparent
                    pixels[pixelIndex]     = 0
                    pixels[pixelIndex + 1] = 0
                    pixels[pixelIndex + 2] = 0
                    pixels[pixelIndex + 3] = 0
                }
            }
        }

        // Convert the pixel array into a CGImage, then to a UIImage
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ), let cgImage = context.makeImage() else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    /// Clears the cached embeddings - call this when switching to a new image
    func clearCache() {
        // cachedImageEmbeddings = nil
        cachedImageHash = nil
    }

    // MARK: - Private

    private func encodeImage(_ image: UIImage, modelSize: Int = 1024) async throws -> SAM2_1LargeImageEncoderFLOAT16Output {
            let imageHash = image.hashValue
            if let cached = cachedEncoderOutput, cachedImageHash == imageHash {
                return cached
            }

            guard let cgImage = image.cgImage else { throw PipelineError.invalidImage }

            // 1. Create the Pixel Buffer (this explicitly forces the safe 32BGRA format)
            let pixelBuffer = try createPixelBuffer(from: cgImage, size: modelSize)

            // 2. Pass the pixel buffer DIRECTLY to the encoder.
            // Do NOT use `MLMultiArray` and do NOT use the `imageWith: cgImage` helper!
            let input = SAM2_1LargeImageEncoderFLOAT16Input(image: pixelBuffer)
            let output = try await imageEncoder.prediction(input: input)

            cachedEncoderOutput = output
            cachedImageHash = imageHash

            return output
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
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:] // <-- ADD THIS LINE
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
}
