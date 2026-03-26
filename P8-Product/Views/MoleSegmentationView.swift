//
//  MoleSegmentationTestView.swift
//  P8-Product
//
//  Created by Simon Thordal on 3/24/26.
//

import SwiftUI
import CoreML

struct MoleSegmentationTestView: View {
    // The image we use to segment. Should be changed to the one captured in images
    @State private var testImage: UIImage? = UIImage(named: "test_mole_image")

    // Segmentation result — just the cropped mask (not a full-size composite)
    @State private var cropMaskImage: UIImage?

    // Loading state
    @State private var isProcessing = false

    // Error handling
    @State private var errorMessage: String?
    @State private var showError = false

    // The segmentor instance
    @State private var segmentor: MoleSegmentor?

    // Tap point and bounding box, both in image-pixel coordinates
    @State private var lastTapPoint: CGPoint?
    @State private var boundingBox: CGRect?

    // Side length of the crop bounding box in image pixels
    private let cropSize: CGFloat = 200

    // No zoom - keeping it simple

    var body: some View {
        NavigationStack {
            ZStack {
                if let image = testImage {
                    imageContent(image: image)
                } else {
                    noImagePlaceholder
                }

                if isProcessing {
                    loadingOverlay
                }
            }
            .navigationTitle("Mole Segmentation Test")
            .toolbar { toolbarContent }
            .alert("Error", isPresented: $showError) {
                Button("OK") { showError = false }
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
            .task { await loadSegmentor() }
        }
    }

    // MARK: - Image layer - SIMPLIFIED, no zoom

    @ViewBuilder
    private func imageContent(image: UIImage) -> some View {
        GeometryReader { geometry in
            ZStack {
                // Base image - scaled to fit
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width, height: geometry.size.height)

                // Bounding box
                if let box = boundingBox {
                    Rectangle()
                        .stroke(Color.yellow, lineWidth: 2)
                        .frame(width: box.width, height: box.height)
                        .position(x: box.midX, y: box.midY)
                }

                // Mask overlay
                if let mask = cropMaskImage, let box = boundingBox {
                    Image(uiImage: mask)
                        .resizable()
                        .frame(width: box.width, height: box.height)
                        .position(x: box.midX, y: box.midY)
                        .opacity(0.5)
                        .blendMode(.multiply)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { location in
                handleTap(at: location, in: geometry.size, image: image)
            }
        }
    }

    // MARK: - Actions

    private func handleTap(at location: CGPoint, in viewSize: CGSize, image: UIImage) {
        guard let segmentor, let cgImage = image.cgImage else { return }
        guard !isProcessing else { return }

        let pixelW = CGFloat(cgImage.width)
        let pixelH = CGFloat(cgImage.height)

        // Calculate the displayed image size (aspect fit)
        let imageAspect = pixelW / pixelH
        let viewAspect = viewSize.width / viewSize.height
        
        let displayedSize: CGSize
        let offset: CGPoint
        
        if imageAspect > viewAspect {
            // Image is wider - fits to width
            displayedSize = CGSize(width: viewSize.width, height: viewSize.width / imageAspect)
            offset = CGPoint(x: 0, y: (viewSize.height - displayedSize.height) / 2)
        } else {
            // Image is taller - fits to height
            displayedSize = CGSize(width: viewSize.height * imageAspect, height: viewSize.height)
            offset = CGPoint(x: (viewSize.width - displayedSize.width) / 2, y: 0)
        }
        
        // Convert tap from view coordinates to image pixel coordinates
        let tapInImage = CGPoint(
            x: (location.x - offset.x) / displayedSize.width * pixelW,
            y: (location.y - offset.y) / displayedSize.height * pixelH
        )
        
        let tap = CGPoint(
            x: max(0, min(pixelW, tapInImage.x)),
            y: max(0, min(pixelH, tapInImage.y))
        )
        
        // Store for display - but we need to convert BACK to view coordinates for drawing!
        lastTapPoint = CGPoint(
            x: offset.x + (tap.x / pixelW) * displayedSize.width,
            y: offset.y + (tap.y / pixelH) * displayedSize.height
        )

        // Build bounding box in image-pixel coordinates
        let halfCrop = cropSize / 2
        let boxX     = max(0, min(pixelW - cropSize, tap.x - halfCrop))
        let boxY     = max(0, min(pixelH - cropSize, tap.y - halfCrop))
        let box      = CGRect(x: boxX, y: boxY,
                              width:  min(cropSize, pixelW),
                              height: min(cropSize, pixelH))
        
        // Convert bounding box to view coordinates for display
        boundingBox = CGRect(
            x: offset.x + (box.origin.x / pixelW) * displayedSize.width,
            y: offset.y + (box.origin.y / pixelH) * displayedSize.height,
            width: (box.width / pixelW) * displayedSize.width,
            height: (box.height / pixelH) * displayedSize.height
        )

        let pointInCrop = CGPoint(x: tap.x - boxX, y: tap.y - boxY)

        Task {
            isProcessing = true
            do {
                guard let croppedCG = cgImage.cropping(to: box) else {
                    throw PipelineError.invalidImage
                }
                let croppedImage = UIImage(cgImage: croppedCG)
                let maskArray    = try await segmentor.segment(image: croppedImage,
                                                               point: pointInCrop,
                                                               modelSize: 1024)
                let maskImage    = try convertMaskToImage(maskArray, targetSize: box.size)

                await MainActor.run {
                    cropMaskImage = maskImage
                    isProcessing  = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Segmentation failed: \(error.localizedDescription)"
                    showError    = true
                    isProcessing = false
                }
            }
        }
    }

    private func loadSegmentor() async {
        do {
            segmentor = try await MoleSegmentor()
        } catch {
            errorMessage = "Failed to load model: \(error.localizedDescription)"
            showError = true
        }
    }

    private func clearSegmentation() {
        cropMaskImage = nil
        lastTapPoint  = nil
        boundingBox   = nil
        segmentor?.clearCache()
    }

    private func resetZoom() {
        // No zoom functionality anymore
    }

    // MARK: - Mask conversion

    private func convertMaskToImage(_ maskArray: MLMultiArray, targetSize: CGSize) throws -> UIImage {
        let shape = maskArray.shape.map { $0.intValue }

        let (maskH, maskW): (Int, Int)
        switch shape.count {
        case 4:  (maskH, maskW) = (shape[2], shape[3])
        case 3:  (maskH, maskW) = (shape[1], shape[2])
        case 2:  (maskH, maskW) = (shape[0], shape[1])
        default: throw PipelineError.renderFailed
        }

        guard let ctx = CGContext(data: nil, width: maskW, height: maskH,
                                  bitsPerComponent: 8, bytesPerRow: maskW,
                                  space: CGColorSpaceCreateDeviceGray(),
                                  bitmapInfo: CGImageAlphaInfo.none.rawValue),
              let buf = ctx.data else {
            throw PipelineError.renderFailed
        }

        let pixels = buf.assumingMemoryBound(to: UInt8.self)
        for y in 0..<maskH {
            for x in 0..<maskW {
                let v: Float
                switch shape.count {
                case 4:  v = maskArray[[0, 0, y, x] as [NSNumber]].floatValue
                case 3:  v = maskArray[[0, y, x] as [NSNumber]].floatValue
                default: v = maskArray[[y, x] as [NSNumber]].floatValue
                }
                pixels[y * maskW + x] = v > 0.5 ? 255 : 0
            }
        }

        guard let cgMask = ctx.makeImage() else { throw PipelineError.renderFailed }
        let maskImage = UIImage(cgImage: cgMask)
        guard maskImage.size != targetSize else { return maskImage }

        UIGraphicsBeginImageContextWithOptions(targetSize, false, 1.0)
        maskImage.draw(in: CGRect(origin: .zero, size: targetSize))
        let resized = UIGraphicsGetImageFromCurrentImageContext() ?? maskImage
        UIGraphicsEndImageContext()
        return resized
    }

    // MARK: - Subviews

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView().scaleEffect(1.5)
                Text("Segmenting...")
                    .foregroundStyle(.white)
                    .font(.headline)
            }
            .padding()
            .background(.black.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var noImagePlaceholder: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("No test image found")
                .font(.headline)
            Text("Add an image named 'test_mole_image' to Assets.xcassets")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding()
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button("Clear") { 
                clearSegmentation() 
            }
            .disabled(cropMaskImage == nil)
        }
        ToolbarItem(placement: .navigationBarLeading) {
            if let point = lastTapPoint {
                Text("Tap: (\(Int(point.x)), \(Int(point.y)))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Helpers

    private func clamp(_ v: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat {
        min(hi, max(lo, v))
    }
}

// MARK: - Preview

#Preview {
    MoleSegmentationTestView()
}
