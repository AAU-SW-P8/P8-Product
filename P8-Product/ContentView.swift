//
//  ContentView.swift
//  coremlTest
//
//  Created by Simon Thordal on 3/12/26.
//

import SwiftUI
import PhotosUI
import CoreML
import CoreImage
import CoreImage.CIFilterBuiltins

struct ContentView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var originalImage: UIImage?
    @State private var segmentedImage: UIImage?
    @State private var isProcessing = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if let originalImage, let segmentedImage {
                    ImageComparisonView(
                        original: originalImage,
                        segmented: segmentedImage
                    )
                } else if isProcessing {
                    ProgressView("Running segmentation...")
                } else {
                    ContentUnavailableView(
                        "No Image Selected",
                        systemImage: "photo.on.rectangle",
                        description: Text("Pick a photo to run segmentation.")
                    )
                }
            }
            .overlay(alignment: .bottom) {
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.caption)
                        .padding()
                }
            }
            .navigationTitle("UNet Segmentation")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    PhotosPicker(
                        selection: $selectedItem,
                        matching: .images
                    ) {
                        Label("Pick Photo", systemImage: "photo.badge.plus")
                    }
                }
            }
            .onChange(of: selectedItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    await loadAndSegment(item: newItem)
                }
            }
        }
    }

    private func loadAndSegment(item: PhotosPickerItem) async {
        isProcessing = true
        errorMessage = nil
        originalImage = nil
        segmentedImage = nil

        defer { isProcessing = false }

        // Load image data from the picker item
        guard let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data),
              let cgImage = uiImage.cgImage else {
            errorMessage = "Failed to load image."
            return
        }

        originalImage = uiImage

        do {
            let segmented = try await runSegmentation(on: cgImage)
            segmentedImage = segmented
        } catch {
            errorMessage = "Segmentation failed: \(error.localizedDescription)"
        }
    }

    private func runSegmentation(on cgImage: CGImage) async throws -> UIImage {
        // Resize the input image to the model's expected 256x256 BGRA
        let modelSize = 256
        let ciContext = CIContext()
        let originalCI = CIImage(cgImage: cgImage)
        let scaleX = CGFloat(modelSize) / originalCI.extent.width
        let scaleY = CGFloat(modelSize) / originalCI.extent.height
        let resizedCI = originalCI.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, modelSize, modelSize, kCVPixelFormatType_32BGRA, nil, &pixelBuffer)
        guard let inputBuffer = pixelBuffer else {
            throw SegmentationError.renderFailed
        }
        ciContext.render(resizedCI, to: inputBuffer)

        // Run the UNet model
        let model = try unet_mole(configuration: MLModelConfiguration())
        let input = unet_moleInput(x: inputBuffer)
        let output = try await model.prediction(input: input)
        let maskArray = output.Identity // [1, 256, 256, 1] Float32

        // Convert the MLMultiArray mask to a grayscale CGImage
        let maskCGImage = try createGrayscaleImage(from: maskArray, width: modelSize, height: modelSize)

        // Scale mask back to original image size and blend
        let maskCI = CIImage(cgImage: maskCGImage)
        let upScaleX = originalCI.extent.width / maskCI.extent.width
        let upScaleY = originalCI.extent.height / maskCI.extent.height
        let scaledMask = maskCI.transformed(by: CGAffineTransform(scaleX: upScaleX, y: upScaleY))

        // Blend: segmented region highlighted, rest replaced with green
        let background = CIImage(color: CIColor(red: 0.2, green: 0.8, blue: 0.3))
            .cropped(to: originalCI.extent)

        let blendFilter = CIFilter.blendWithMask()
        blendFilter.inputImage = originalCI
        blendFilter.backgroundImage = background
        blendFilter.maskImage = scaledMask

        guard let outputCI = blendFilter.outputImage,
              let outputCG = ciContext.createCGImage(outputCI, from: originalCI.extent) else {
            throw SegmentationError.renderFailed
        }

        return UIImage(cgImage: outputCG)
    }

    /// Converts a [1, H, W, 1] MLMultiArray of floats (0..1) into a grayscale CGImage.
    private func createGrayscaleImage(from array: MLMultiArray, width: Int, height: Int) throws -> CGImage {
        let count = width * height
        var pixels = [UInt8](repeating: 0, count: count)

        let pointer = array.dataPointer.bindMemory(to: Float32.self, capacity: count)
        for i in 0..<count {
            let value = min(max(pointer[i], 0), 1)
            pixels[i] = UInt8(value * 255)
        }

        let colorSpace = CGColorSpace(name: CGColorSpace.linearGray)!
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ), let cgImage = context.makeImage() else {
            throw SegmentationError.renderFailed
        }

        return cgImage
    }
}

enum SegmentationError: LocalizedError {
    case renderFailed

    var errorDescription: String? {
        switch self {
        case .renderFailed:
            return "Failed to render the segmented image."
        }
    }
}


struct ImageComparisonView: View {
    let original: UIImage
    let segmented: UIImage

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 8) {
                Text("Original")
                    .font(.headline)
                Image(uiImage: original)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 8) {
                Text("Segmented")
                    .font(.headline)
                Image(uiImage: segmented)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
