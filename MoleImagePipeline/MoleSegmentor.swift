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
        guard let visionURL = Bundle.main.url(forResource: "SAM3.1_ImageEncoder_FP16", withExtension: "mlmodelc")
            ?? Bundle.main.url(forResource: "SAM3.1_ImageEncoder_FP16", withExtension: "mlpackage") else {
            throw PipelineError.modelNotFound(name: "SAM3.1_ImageEncoder_FP16")
        }

        // Load Text Encoder
        guard let textURL = Bundle.main.url(forResource: "SAM3_TextEncoder_FP16", withExtension: "mlmodelc")
            ?? Bundle.main.url(forResource: "SAM3.1_TextEncoder_FP16", withExtension: "mlpackage") else {
            throw PipelineError.modelNotFound(name: "SAM3.1_TextEncoder_FP16")
        }

        // Load Decoder
        guard let decoderURL = Bundle.main.url(forResource: "SAM3_Detector_FP16", withExtension: "mlmodelc")
            ?? Bundle.main.url(forResource: "SAM3.1_Detector_FP16", withExtension: "mlpackage") else {
            throw PipelineError.modelNotFound(name: "SAM3.1_Detector_FP16")
        }

        let config = MLModelConfiguration()
        config.computeUnits = .all

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
    /// Returns the input image with colored mask overlays, bounding boxes, and
    /// per-detection labels (ID + score), or nil if no moles were detected.
    func segment(image: UIImage, confidenceThreshold: Float = 0.3, nmsThreshold: Float = 1.0) throws -> UIImage? {
        // 1. Encode image through vision encoder
        print("🖼️ Encoding image…")
        let visionOutput = try encodeImage(image)

        // Verify vision encoder outputs exist (FPN multi-scale features + positional encoding)
        guard let fpnFeat0 = visionOutput.featureValue(for: "x_495"),   // [1,256,288,288]
              let fpnFeat1 = visionOutput.featureValue(for: "x_497"),   // [1,256,144,144]
              let fpnFeat2 = visionOutput.featureValue(for: "x_499"),   // [1,256,72,72]
              let visPos   = visionOutput.featureValue(for: "const_762") // [1,256,72,72]
        else {
            print("❌ Vision encoder missing expected output features")
            print("   Available features: \(visionOutput.featureNames.joined(separator: ", "))")
            throw PipelineError.unexpectedModelOutput
        }

        guard let textFeat = textFeatures.featureValue(for: "var_2489"),
              let textMask = textFeatures.featureValue(for: "var_5") else {
            print("❌ Text encoder missing expected output features")
            throw PipelineError.unexpectedModelOutput
        }

        // 2. Prepare decoder inputs — FPN features + text grounding
        let decoderInput = try MLDictionaryFeatureProvider(dictionary: [
            "fpn_feat0": fpnFeat0,
            "fpn_feat1": fpnFeat1,
            "fpn_feat2": fpnFeat2,
            "vis_pos": visPos,
            "text_features": textFeat,
            "text_mask": textMask
        ])

        // 3. Run decoder
        print("🧠 Running decoder…")
        let decoderOutput = try decoder.prediction(from: decoderInput)

        guard let masks = decoderOutput.featureValue(for: "var_5020")?.multiArrayValue,
              let scores = decoderOutput.featureValue(for: "var_4806")?.multiArrayValue,
              let boxes = decoderOutput.featureValue(for: "var_4734")?.multiArrayValue else {
            print("❌ Decoder missing expected output features")
            print("   Available features: \(decoderOutput.featureNames.joined(separator: ", "))")
            throw PipelineError.unexpectedModelOutput
        }

        print("📊 Scores shape: \(scores.shape), Boxes shape: \(boxes.shape), Masks shape: \(masks.shape)")

        // 4. Filter detections by confidence
        struct RawDetection {
            let index: Int
            let prob: Float
            let box: CGRect // normalized [0,1] coordinates
        }

        var rawDetections: [RawDetection] = []
        for i in 0..<200 {
            let prob = scores[[0, i] as [NSNumber]].floatValue
            if prob >= confidenceThreshold {
                // Extract box — DETR-style [cx, cy, w, h] normalized to [0,1]
                let cx = CGFloat(boxes[[0, i, 0] as [NSNumber]].floatValue)
                let cy = CGFloat(boxes[[0, i, 1] as [NSNumber]].floatValue)
                let w  = CGFloat(boxes[[0, i, 2] as [NSNumber]].floatValue)
                let h  = CGFloat(boxes[[0, i, 3] as [NSNumber]].floatValue)
                let box = CGRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h)
                rawDetections.append(RawDetection(index: i, prob: prob, box: box))
            }
        }

        guard !rawDetections.isEmpty else {
            print("⚠️ No detections above threshold \(confidenceThreshold)")
            return nil
        }

        // 5. Sort by confidence and apply NMS to remove overlapping detections
        rawDetections.sort { $0.prob > $1.prob }

        var kept: [RawDetection] = []
        for det in rawDetections {
            let dominated = kept.contains { Self.iou($0.box, det.box) > nmsThreshold }
            if !dominated {
                kept.append(det)
            }
        }

        print("✅ Found \(kept.count) moles (from \(rawDetections.count) candidates after NMS)")
        for det in kept {
            print("   🎯 Detection \(det.index): prob=\(String(format: "%.3f", det.prob))")
        }

        // 6. Render annotated overlay on the original image
        let detections = kept.map { (index: $0.index, prob: $0.prob, box: $0.box) }
        return createAnnotatedImage(from: masks, detections: detections, baseImage: image)
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
        let tokenIds: [Int32] = [49406, 23529, 49407] + Array(repeating: 0, count: 29)

        let inputIds = try MLMultiArray(shape: [1, 32], dataType: .int32)

        for i in 0..<32 {
            inputIds[[0, i] as [NSNumber]] = NSNumber(value: tokenIds[i])
        }

        let input = try MLDictionaryFeatureProvider(dictionary: [
            "token_ids": MLFeatureValue(multiArray: inputIds)
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
            "image": MLFeatureValue(multiArray: imageArray)
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

    /// Converts a BGRA CVPixelBuffer to a Float16 MLMultiArray in [1, 3, H, W] layout (RGB, normalised to [-1, 1]).
    /// SAM3 expects Normalize(mean=[0.5, 0.5, 0.5], std=[0.5, 0.5, 0.5]), i.e. (pixel/255 - 0.5) / 0.5 = pixel/127.5 - 1.
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
                // BGRA → RGB, normalized to [-1, 1]
                let b = Float(bytes[pixelOffset])     / 127.5 - 1.0
                let g = Float(bytes[pixelOffset + 1]) / 127.5 - 1.0
                let r = Float(bytes[pixelOffset + 2]) / 127.5 - 1.0

                let spatial = y * size + x
                dataPtr[0 * hw + spatial] = Float16(r)
                dataPtr[1 * hw + spatial] = Float16(g)
                dataPtr[2 * hw + spatial] = Float16(b)
            }
        }

        return array
    }

    // MARK: - NMS

    /// Computes Intersection over Union between two rectangles.
    private static func iou(_ a: CGRect, _ b: CGRect) -> Float {
        let intersection = a.intersection(b)
        if intersection.isNull { return 0 }
        let interArea = Float(intersection.width * intersection.height)
        let unionArea = Float(a.width * a.height + b.width * b.height) - interArea
        return unionArea > 0 ? interArea / unionArea : 0
    }

    // MARK: - Mask Rendering

    /// Distinct colors for each detection (RGB tuples, 0-255).
    private static let palette: [(UInt8, UInt8, UInt8)] = [
        (230,  25,  75), // red
        ( 60, 180,  75), // green
        (  0, 130, 200), // blue
        (255, 225,  25), // yellow
        (245, 130,  48), // orange
        (145,  30, 180), // purple
        ( 70, 240, 240), // cyan
        (240,  50, 230), // magenta
        (210, 245,  60), // lime
        (250, 190, 212), // pink
    ]

    /// Renders the base image with per-detection colored mask overlays,
    /// bounding boxes, and ID + score labels.
    private func createAnnotatedImage(
        from masks: MLMultiArray,
        detections: [(index: Int, prob: Float, box: CGRect)],
        baseImage: UIImage
    ) -> UIImage? {
        let imageSize = baseImage.size
        let maskH = Self.maskSize
        let maskW = Self.maskSize
        let scaleX = imageSize.width  / CGFloat(maskW)
        let scaleY = imageSize.height / CGFloat(maskH)

        // Draw everything using UIKit graphics
        UIGraphicsBeginImageContextWithOptions(imageSize, true, 0.0)
        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }

        // Draw the original image as background
        baseImage.draw(in: CGRect(origin: .zero, size: imageSize))

        let maskAlpha: CGFloat = 0.35

        for (detId, det) in detections.enumerated() {
            let color = Self.palette[detId % Self.palette.count]
            let r = CGFloat(color.0) / 255.0
            let g = CGFloat(color.1) / 255.0
            let b = CGFloat(color.2) / 255.0

            // Draw semi-transparent mask pixels and track bounds for the bounding box
            ctx.setFillColor(red: r, green: g, blue: b, alpha: maskAlpha)
            var minMaskX = maskW, minMaskY = maskH, maxMaskX = 0, maxMaskY = 0
            for y in 0..<maskH {
                for x in 0..<maskW {
                    let logit = masks[[0, det.index, y, x] as [NSNumber]].floatValue
                    if logit > 0 {
                        let rect = CGRect(
                            x: CGFloat(x) * scaleX,
                            y: CGFloat(y) * scaleY,
                            width: scaleX + 1,
                            height: scaleY + 1
                        )
                        ctx.fill(rect)
                        minMaskX = min(minMaskX, x)
                        minMaskY = min(minMaskY, y)
                        maxMaskX = max(maxMaskX, x)
                        maxMaskY = max(maxMaskY, y)
                    }
                }
            }
            let boxRect = CGRect(
                x: CGFloat(minMaskX) * scaleX,
                y: CGFloat(minMaskY) * scaleY,
                width: CGFloat(maxMaskX - minMaskX + 1) * scaleX,
                height: CGFloat(maxMaskY - minMaskY + 1) * scaleY
            )
            ctx.setStrokeColor(red: r, green: g, blue: b, alpha: 1.0)
            ctx.setLineWidth(2.0)
            ctx.stroke(boxRect)

            // Draw label
            let label = String(format: "mole %d  %.0f%%", detId + 1, det.prob * 100)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: max(imageSize.width / 40, 12)),
                .foregroundColor: UIColor.white,
                .backgroundColor: UIColor(red: r, green: g, blue: b, alpha: 0.75),
            ]
            let labelSize = (label as NSString).size(withAttributes: attrs)
            let labelOrigin = CGPoint(
                x: boxRect.minX,
                y: max(boxRect.minY - labelSize.height - 2, 0)
            )
            (label as NSString).draw(at: labelOrigin, withAttributes: attrs)
        }

        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return result
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
