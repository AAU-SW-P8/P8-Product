//
//  MoleSegmentor.swift
//  P8-Product
//
//  Created by Simon Thordal on 3/16/26.
//
import CoreML
import UIKit

class MoleSegmentor {

    // MARK: - Properties

    // SAM3 uses three models: Vision Encoder, Text Encoder, and Decoder
    private let visionEncoder: MLModel
    private let textEncoder: MLModel
    private let decoder: MLModel

    private let ciContext = CIContext()

    // Cache the vision encoder output for repeated segmentation on the same image
    private var cachedVisionOutput: MLFeatureProvider?
    private var cachedImageHash: Int?

    // Pre-encoded text features (prompt is fixed to "moles")
    private let textFeatures: MLFeatureProvider

    static let inputSize = 1008
    static let maskSize = 288

    // MARK: - Init

    init() async throws {
        // Load Vision Encoder
        guard let visionURL = Bundle.main.url(forResource: "sam3-vision-encoder", withExtension: "mlmodelc")
            ?? Bundle.main.url(forResource: "sam3-vision-encoder", withExtension: "mlpackage") else {
            throw PipelineError.modelNotFound(name: "sam3-vision-encoder")
        }

        // Load Text Encoder
        guard let textURL = Bundle.main.url(forResource: "sam3-text-encoder", withExtension: "mlmodelc")
            ?? Bundle.main.url(forResource: "sam3-text-encoder", withExtension: "mlpackage") else {
            throw PipelineError.modelNotFound(name: "sam3-text-encoder")
        }

        // Load Decoder
        guard let decoderURL = Bundle.main.url(forResource: "sam3-decoder", withExtension: "mlmodelc")
            ?? Bundle.main.url(forResource: "sam3-decoder", withExtension: "mlpackage") else {
            throw PipelineError.modelNotFound(name: "sam3-decoder")
        }

        let config = MLModelConfiguration()
        config.computeUnits = .cpuOnly

        print("📦 Loading SAM3 vision encoder…")
        self.visionEncoder = try await MLModel.load(contentsOf: visionURL, configuration: config)
        print("📦 Loading SAM3 text encoder…")
        self.textEncoder = try await MLModel.load(contentsOf: textURL, configuration: config)
        print("📦 Loading SAM3 decoder…")
        self.decoder = try await MLModel.load(contentsOf: decoderURL, configuration: config)

        // Pre-encode the text prompt "moles" once at init
        print("📝 Encoding text prompt 'moles'…")
        self.textFeatures = try MoleSegmentor.encodeText(with: self.textEncoder)
        print("✅ SAM3 models loaded and text encoded")
    }

    // MARK: - Public

    /// Segments moles in the image using the text prompt "moles".
    /// Returns a semi-transparent overlay image (red = mole) sized to match the input,
    /// or nil if no moles were detected above the confidence threshold.
    func segment(image: UIImage, confidenceThreshold: Float = 0.01) throws -> UIImage? {
        // 1. Encode image through vision encoder
        print("🖼️ Encoding image…")
        let visionOutput = try encodeImage(image)

        // Verify vision encoder outputs exist
        guard let fpn0 = visionOutput.featureValue(for: "fpn_feat_0"),
              let fpn1 = visionOutput.featureValue(for: "fpn_feat_1"),
              let fpn2 = visionOutput.featureValue(for: "fpn_feat_2"),
              let pos2 = visionOutput.featureValue(for: "fpn_pos_2") else {
            print("❌ Vision encoder missing expected output features")
            print("   Available features: \(visionOutput.featureNames.joined(separator: ", "))")
            throw PipelineError.unexpectedModelOutput
        }

        guard let textFeat = textFeatures.featureValue(for: "text_features"),
              let textMask = textFeatures.featureValue(for: "text_mask") else {
            print("❌ Text encoder missing expected output features")
            throw PipelineError.unexpectedModelOutput
        }

        // 2. Prepare decoder inputs — no box prompts, text-only grounding
        let inputBoxes = try MLMultiArray.zeros(shape: [1, 5, 4], dataType: .float16)
        let inputBoxesLabels = try MLMultiArray.zeros(shape: [1, 5], dataType: .int32)

        let decoderInput = try MLDictionaryFeatureProvider(dictionary: [
            "fpn_feat_0": fpn0,
            "fpn_feat_1": fpn1,
            "fpn_feat_2": fpn2,
            "fpn_pos_2": pos2,
            "text_features": textFeat,
            "text_mask": textMask,
            "input_boxes": MLFeatureValue(multiArray: inputBoxes),
            "input_boxes_labels": MLFeatureValue(multiArray: inputBoxesLabels)
        ])

        // 3. Run decoder
        print("🧠 Running decoder…")
        let decoderOutput = try decoder.prediction(from: decoderInput)

        guard let masks = decoderOutput.featureValue(for: "var_4027")?.multiArrayValue,
              let scores = decoderOutput.featureValue(for: "var_3862")?.multiArrayValue else {
            print("❌ Decoder missing expected output features")
            print("   Available features: \(decoderOutput.featureNames.joined(separator: ", "))")
            throw PipelineError.unexpectedModelOutput
        }

        print("📊 Scores shape: \(scores.shape), dataType: \(scores.dataType.rawValue)")
        print("📊 Masks shape: \(masks.shape), dataType: \(masks.dataType.rawValue)")

        // 4. Filter detections by confidence — use safe .floatValue accessor
        //    (CoreML may promote Float16 → Float32 at runtime)
        var confidentIndices: [Int] = []
        for i in 0..<200 {
            let logit = scores[[0, i] as [NSNumber]].floatValue
            let prob = 1.0 / (1.0 + exp(-logit))
            if prob >= confidenceThreshold {
                confidentIndices.append(i)
                print("🎯 Detection \(i): logit=\(logit), prob=\(prob)")
            }
        }

        guard !confidentIndices.isEmpty else {
            print("⚠️ No detections above threshold \(confidenceThreshold)")
            return nil
        }

        print("✅ Found \(confidentIndices.count) moles")

        // 5. Combine masks of all confident detections into one overlay
        return createCombinedMask(from: masks, indices: confidentIndices, imageSize: image.size)
    }

    /// Clears the cached image embeddings — call when switching to a new image.
    func clearCache() {
        cachedVisionOutput = nil
        cachedImageHash = nil
    }

    // MARK: - Text Encoding

    /// BERT-tokenises the prompt "moles" and runs it through the text encoder.
    /// Token IDs: [CLS]=101  mole=16709  ##s=2015  [SEP]=102  + 28×[PAD]=0
    private static func encodeText(with encoder: MLModel) throws -> MLFeatureProvider {
        let tokenIds: [Int32]      = [101, 16709, 2015, 102] + Array(repeating: 0, count: 28)
        let attentionMask: [Int32] = [1, 1, 1, 1]            + Array(repeating: 0, count: 28)

        let inputIds = try MLMultiArray(shape: [1, 32], dataType: .int32)
        let mask     = try MLMultiArray(shape: [1, 32], dataType: .int32)

        for i in 0..<32 {
            inputIds[[0, i] as [NSNumber]] = NSNumber(value: tokenIds[i])
            mask[[0, i] as [NSNumber]]     = NSNumber(value: attentionMask[i])
        }

        let input = try MLDictionaryFeatureProvider(dictionary: [
            "input_ids":      MLFeatureValue(multiArray: inputIds),
            "attention_mask": MLFeatureValue(multiArray: mask)
        ])

        let output = try encoder.prediction(from: input)
        print("📝 Text encoder output features: \(output.featureNames.joined(separator: ", "))")
        return output
    }

    // MARK: - Image Encoding

    private func encodeImage(_ image: UIImage) throws -> MLFeatureProvider {
        let imageHash = image.hashValue
        if let cached = cachedVisionOutput, cachedImageHash == imageHash {
            print("📦 Using cached vision embeddings")
            return cached
        }

        guard let cgImage = image.cgImage else { throw PipelineError.invalidImage }

        let size = Self.inputSize
        let pixelBuffer = try createPixelBuffer(from: cgImage, size: size)
        let imageArray  = try pixelBufferToMLMultiArray(pixelBuffer, size: size)

        let input = try MLDictionaryFeatureProvider(dictionary: [
            "images": MLFeatureValue(multiArray: imageArray)
        ])

        let output = try visionEncoder.prediction(from: input)
        print("🖼️ Vision encoder output features: \(output.featureNames.joined(separator: ", "))")
        cachedVisionOutput = output
        cachedImageHash = imageHash
        return output
    }

    // MARK: - Pixel Buffer Helpers

    private func createPixelBuffer(from cgImage: CGImage, size: Int) throws -> CVPixelBuffer {
        let originalCI = CIImage(cgImage: cgImage)
        let scaleX = CGFloat(size) / originalCI.extent.width
        let scaleY = CGFloat(size) / originalCI.extent.height
        let resizedCI = originalCI.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        let bufferAttributes: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]

        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, size, size,
                            kCVPixelFormatType_32BGRA,
                            bufferAttributes as CFDictionary,
                            &pixelBuffer)

        guard let buffer = pixelBuffer else {
            print("❌ CVPixelBufferCreate failed for size \(size)×\(size)")
            throw PipelineError.renderFailed
        }
        ciContext.render(resizedCI, to: buffer)
        return buffer
    }

    /// Converts a BGRA CVPixelBuffer to a Float16 MLMultiArray in [1, 3, H, W] layout (RGB, normalised to 0-1).
    private func pixelBufferToMLMultiArray(_ pixelBuffer: CVPixelBuffer, size: Int) throws -> MLMultiArray {
        let array = try MLMultiArray(shape: [1, 3, size as NSNumber, size as NSNumber], dataType: .float16)

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            print("❌ CVPixelBufferGetBaseAddress returned nil")
            throw PipelineError.renderFailed
        }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let bytes = baseAddress.assumingMemoryBound(to: UInt8.self)
        let hw = size * size

        // Use unsafe pointer for performance — we own this array so Float16 is guaranteed
        let dataPtr = array.dataPointer.bindMemory(to: Float16.self, capacity: 3 * hw)

        for y in 0..<size {
            for x in 0..<size {
                let pixelOffset = y * bytesPerRow + x * 4
                // BGRA → RGB
                let b = Float(bytes[pixelOffset])     / 255.0
                let g = Float(bytes[pixelOffset + 1]) / 255.0
                let r = Float(bytes[pixelOffset + 2]) / 255.0

                let spatial = y * size + x
                dataPtr[0 * hw + spatial] = Float16(r)
                dataPtr[1 * hw + spatial] = Float16(g)
                dataPtr[2 * hw + spatial] = Float16(b)
            }
        }

        return array
    }

    // MARK: - Mask Rendering

    /// Combines all confident detection masks into a single semi-transparent red overlay,
    /// then resizes to match the original image dimensions.
    private func createCombinedMask(from masks: MLMultiArray, indices: [Int], imageSize: CGSize) -> UIImage? {
        let h = Self.maskSize  // 288
        let w = Self.maskSize
        let hw = h * w
        var pixels = [UInt8](repeating: 0, count: w * h * 4)

        // Use safe .floatValue accessor — works regardless of runtime data type
        for y in 0..<h {
            for x in 0..<w {
                let spatial = y * w + x
                let pixelIdx = spatial * 4

                for detIdx in indices {
                    let logit = masks[[0, detIdx, y, x] as [NSNumber]].floatValue
                    if logit > 7 { // Change this number
                        pixels[pixelIdx]     = 255  // R
                        pixels[pixelIdx + 1] = 0    // G
                        pixels[pixelIdx + 2] = 0    // B
                        pixels[pixelIdx + 3] = 128  // A (semi-transparent)
                        break
                    }
                }
            }
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let context = CGContext(
            data: &pixels, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: w * 4,
            space: colorSpace, bitmapInfo: bitmapInfo.rawValue
        ), let cgMask = context.makeImage() else {
            return nil
        }

        // Resize to match the original image
        let maskImage = UIImage(cgImage: cgMask)
        guard maskImage.size != imageSize else { return maskImage }

        UIGraphicsBeginImageContextWithOptions(imageSize, false, 0.0)
        maskImage.draw(in: CGRect(origin: .zero, size: imageSize))
        let resized = UIGraphicsGetImageFromCurrentImageContext() ?? maskImage
        UIGraphicsEndImageContext()

        return resized
    }
}

// MARK: - MLMultiArray Helper

private extension MLMultiArray {
    /// Creates a zero-initialised MLMultiArray.
    static func zeros(shape: [NSNumber], dataType: MLMultiArrayDataType) throws -> MLMultiArray {
        let array = try MLMultiArray(shape: shape, dataType: dataType)
        let byteCount = array.count * (dataType == .float16 ? 2 : (dataType == .int32 ? 4 : 4))
        memset(array.dataPointer, 0, byteCount)
        return array
    }
}
