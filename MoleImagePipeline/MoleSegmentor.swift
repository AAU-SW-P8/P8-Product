//
//  MoleSegmentor.swift
//  P8-Product
//
//  Created by Simon Thordal on 3/16/26.
//
import CoreML
import UIKit

class MoleSegmentor {
    // SAM3 uses three models: Vision Encoder, Text Encoder, and Decoder.
    // Unlike SAM2 (point prompts), SAM3 uses text + bounding box prompts —
    // which lets us target "mole" specifically.
    private let visionEncoder: sam3_vision_encoder
    private let textEncoder: sam3_text_encoder
    private let decoder: sam3_decoder

    private let ciContext = CIContext()

    // Vision encoder output is cached per image (expensive to recompute)
    private var cachedVisionOutput: sam3_vision_encoderOutput?
    private var cachedImageHash: Int?

    // Text encoder output is cached for the lifetime of the instance
    // since our text prompt ("mole") never changes.
    private var cachedTextOutput: sam3_text_encoderOutput?

    // CLIP token IDs for the text prompt "mole".
    // Format: [<|startoftext|>, <token for "mole">, <|endoftext|>, 0, 0, ...]
    //
    // To regenerate these for a different prompt, run in Python:
    //   import clip
    //   tokens = clip.tokenize(["mole"]).tolist()[0]
    //   print(tokens[:5])  # Shows leading non-zero tokens
    //
    // Standard CLIP special tokens: start=49406, end=49407, pad=0
    private static let clipTextPrompt = "mole"
    private static let clipInputIds: [Int32] = {
        var ids = [Int32](repeating: 0, count: 32)
        ids[0] = 49406  // <|startoftext|>
        ids[1] = 22020  // "mole" — verify with: clip.tokenize(["mole"])
        ids[2] = 49407  // <|endoftext|>
        return ids
    }()
    private static let clipAttentionMask: [Int32] = {
        var mask = [Int32](repeating: 0, count: 32)
        mask[0] = 1
        mask[1] = 1
        mask[2] = 1
        return mask
    }()

    init() async throws {
        let config = MLModelConfiguration()
        config.computeUnits = .cpuOnly

        guard let visionURL = Bundle.main.url(forResource: "sam3-vision-encoder", withExtension: "mlmodelc")
            ?? Bundle.main.url(forResource: "sam3-vision-encoder", withExtension: "mlpackage") else {
            throw PipelineError.modelNotFound(name: "sam3-vision-encoder")
        }
        guard let textURL = Bundle.main.url(forResource: "sam3-text-encoder", withExtension: "mlmodelc")
            ?? Bundle.main.url(forResource: "sam3-text-encoder", withExtension: "mlpackage") else {
            throw PipelineError.modelNotFound(name: "sam3-text-encoder")
        }
        guard let decoderURL = Bundle.main.url(forResource: "sam3-decoder", withExtension: "mlmodelc")
            ?? Bundle.main.url(forResource: "sam3-decoder", withExtension: "mlpackage") else {
            throw PipelineError.modelNotFound(name: "sam3-decoder")
        }

        self.visionEncoder = try await sam3_vision_encoder.load(contentsOf: visionURL, configuration: config)
        self.textEncoder   = try await sam3_text_encoder.load(contentsOf: textURL, configuration: config)
        self.decoder       = try await sam3_decoder.load(contentsOf: decoderURL, configuration: config)
    }

    // MARK: - Public API

    /// Segment a mole at the tapped point.
    /// - Parameters:
    ///   - image: The source image.
    ///   - point: The tap point in the image's coordinate space.
    ///   - boxPadding: How far to expand the bounding box from the tap point (in normalised 0–1 units).
    /// - Returns: The raw low-resolution mask logits from the decoder.
    func segment(image: UIImage, point: CGPoint, modelSize: Int = 1008, boxPadding: Float = 0.15) async throws -> MLMultiArray {
        // 1. Encode the image (FPN features)
        let visionOutput = try await encodeImage(image, modelSize: modelSize)
        print("📸 Vision encoder fpn_feat_0[0]: \(visionOutput.fpn_feat_0[0])")

        // 2. Encode the text prompt "mole" (cached after first call)
        let textOutput = try await encodeText()
        print("📝 Text encoder text_features[0]: \(textOutput.text_features[0])")

        guard let cgImage = image.cgImage else { throw PipelineError.invalidImage }

        // 3. Build a bounding box centred on the tap point.
        //    SAM3 expects normalised coordinates [x1, y1, x2, y2] in the model's
        //    1024×1024 coordinate space (i.e. pixel values 0–1024).
        let scaleX = Float(modelSize) / Float(cgImage.width)
        let scaleY = Float(modelSize) / Float(cgImage.height)
        let cx = Float(point.x) * scaleX
        let cy = Float(point.y) * scaleY
        let pad = boxPadding * Float(modelSize)

        let x1 = max(0, cx - pad)
        let y1 = max(0, cy - pad)
        let x2 = min(Float(modelSize), cx + pad)
        let y2 = min(Float(modelSize), cy + pad)

        // input_boxes shape: [1, 5, 4]  — batch x num_boxes x (x1, y1, x2, y2)
        let inputBoxes = try MLMultiArray(shape: [1, 5, 4], dataType: .float32)
        inputBoxes[[0, 0, 0] as [NSNumber]] = NSNumber(value: x1)
        inputBoxes[[0, 0, 1] as [NSNumber]] = NSNumber(value: y1)
        inputBoxes[[0, 0, 2] as [NSNumber]] = NSNumber(value: x2)
        inputBoxes[[0, 0, 3] as [NSNumber]] = NSNumber(value: y2)

        // input_boxes_labels shape: [1]  — 1 = valid foreground box
        let inputBoxesLabels = try MLMultiArray(shape: [1, 5], dataType: .float32)
        inputBoxesLabels[[0, 0] as [NSNumber]] = 1.0

        // 4. Run the decoder
        let decoderInput = sam3_decoderInput(
            fpn_feat_0: visionOutput.fpn_feat_0,
            fpn_feat_1: visionOutput.fpn_feat_1,
            fpn_feat_2: visionOutput.fpn_feat_2,
            fpn_pos_2: visionOutput.fpn_pos_2,
            text_features: textOutput.text_features,
            text_mask: textOutput.text_mask,
            input_boxes: inputBoxes,
            input_boxes_labels: inputBoxesLabels
        )
        let decoderOutput = try await decoder.prediction(input: decoderInput)
        print("🎭 Decoder output var_4027[0]: \(decoderOutput.var_4027[0])")

        // var_4027 is the primary mask output (low-res logits)
        return decoderOutput.var_4027
    }

    // MARK: - Mask Rendering

    /// Converts the raw mask logits into a semi-transparent overlay UIImage.
    func createMaskImage(from mlArray: MLMultiArray) -> UIImage? {
        let shape = mlArray.shape
        let height = shape[shape.count - 2].intValue
        let width  = shape[shape.count - 1].intValue

        var pixels = [UInt8](repeating: 0, count: width * height * 4)

        guard let pointer = try? UnsafeBufferPointer<Float32>(mlArray) else {
            print("Failed to access MLMultiArray data")
            return nil
        }

        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                let value = pointer[index]
                let pixelIndex = index * 4

                // Logit > 0 → inside the mole; paint with a semi-transparent red overlay
                if value > 0.0 {
                    pixels[pixelIndex]     = 255  // R
                    pixels[pixelIndex + 1] = 0    // G
                    pixels[pixelIndex + 2] = 0    // B
                    pixels[pixelIndex + 3] = 128  // A (semi-transparent)
                }
                // else: transparent background (already zero-filled)
            }
        }

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

    /// Clears the image embedding cache — call this when switching to a new image.
    func clearCache() {
        cachedVisionOutput = nil
        cachedImageHash = nil
        // Note: cachedTextOutput is intentionally kept; the "mole" prompt never changes.
    }

    // MARK: - Private helpers

    private func encodeImage(_ image: UIImage, modelSize: Int) async throws -> sam3_vision_encoderOutput {
        let imageHash = image.hashValue
        if let cached = cachedVisionOutput, cachedImageHash == imageHash {
            return cached
        }

        guard let cgImage = image.cgImage else { throw PipelineError.invalidImage }
        let imageArray = try createImageArray(from: cgImage, size: modelSize)

        let input = sam3_vision_encoderInput(images: imageArray)
        let output = try await visionEncoder.prediction(input: input)

        cachedVisionOutput = output
        cachedImageHash = imageHash
        return output
    }

    private func encodeText() async throws -> sam3_text_encoderOutput {
        if let cached = cachedTextOutput {
            return cached
        }

        let inputIds = try MLMultiArray(shape: [1, 32], dataType: .int32)
        let attentionMask = try MLMultiArray(shape: [1, 32], dataType: .int32)

        for i in 0..<32 {
            inputIds[[0, i] as [NSNumber]]     = NSNumber(value: MoleSegmentor.clipInputIds[i])
            attentionMask[[0, i] as [NSNumber]] = NSNumber(value: MoleSegmentor.clipAttentionMask[i])
        }

        let input = sam3_text_encoderInput(input_ids: inputIds, attention_mask: attentionMask)
        let output = try await textEncoder.prediction(input: input)

        cachedTextOutput = output
        return output
    }

    // ImageNet mean/std used by CLIP-based models (SAM3 uses CLIP vision backbone)
    private static let imagenetMean: (Float, Float, Float) = (0.485, 0.456, 0.406)
    private static let imagenetStd:  (Float, Float, Float) = (0.229, 0.224, 0.225)

    /// Resizes `cgImage` to `size`×`size`, then returns a float32 MLMultiArray
    /// of shape [1, 3, size, size] with ImageNet-normalised channel-first values.
    private func createImageArray(from cgImage: CGImage, size: Int) throws -> MLMultiArray {
        // Resize via CIImage → CVPixelBuffer (BGRA)
        let ciImage = CIImage(cgImage: cgImage)
        let scaleX = CGFloat(size) / ciImage.extent.width
        let scaleY = CGFloat(size) / ciImage.extent.height
        let resized = ciImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, size, size,
                            kCVPixelFormatType_32BGRA,
                            [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary,
                            &pixelBuffer)
        guard let buffer = pixelBuffer else { throw PipelineError.renderFailed }
        ciContext.render(resized, to: buffer)

        // Build MLMultiArray [1, 3, size, size]
        let array = try MLMultiArray(shape: [1, 3, size as NSNumber, size as NSNumber],
                                     dataType: .float32)
        let floatPtr = array.dataPointer.assumingMemoryBound(to: Float32.self)
        let channelStride = size * size

        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let baseAddress = CVPixelBufferGetBaseAddress(buffer) else {
            throw PipelineError.renderFailed
        }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let bytePtr = baseAddress.assumingMemoryBound(to: UInt8.self)

        let (mr, mg, mb) = MoleSegmentor.imagenetMean
        let (sr, sg, sb) = MoleSegmentor.imagenetStd

        for y in 0..<size {
            for x in 0..<size {
                let px = y * bytesPerRow + x * 4  // BGRA layout
                let r = Float(bytePtr[px + 2]) / 255.0
                let g = Float(bytePtr[px + 1]) / 255.0
                let b = Float(bytePtr[px])     / 255.0
                let idx = y * size + x
                floatPtr[idx]                     = (r - mr) / sr
                floatPtr[channelStride + idx]     = (g - mg) / sg
                floatPtr[2 * channelStride + idx] = (b - mb) / sb
            }
        }

        return array
    }
}
