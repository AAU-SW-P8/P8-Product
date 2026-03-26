//
//  MoleSegmentationTestView.swift
//  P8-Product
//
//  Created by Simon Thordal on 3/24/26.
//

import SwiftUI
import CoreML

/// A view that lets the user tap on a mole image to trigger Edge-SAM segmentation.
///
/// The image is displayed aspect-fit. When the user taps, a `cropSize × cropSize`
/// bounding box is centred on the tap and only that crop is sent to the model,
/// which keeps inference fast and improves accuracy for small moles.
/// The resulting mask is composited back at the bounding-box position.
struct MoleSegmentationTestView: View {

    // MARK: - State

    /// The image to segment. Replace with the image captured by the camera.
    @State private var testImage: UIImage? = UIImage(named: "test_mole_image")

    /// The segmentation mask for the last bounding-box crop.
    @State private var cropMaskImage: UIImage?

    /// `true` while the segmentation pipeline is running.
    @State private var isProcessing = false

    /// Holds the localised error message when segmentation fails.
    @State private var errorMessage: String?

    /// Controls presentation of the error alert.
    @State private var showError = false

    /// The loaded Edge-SAM model wrapper, initialised asynchronously on appear.
    @State private var segmentor: MoleSegmentor?

    /// The last tap location in *view* coordinates, used to show debug info in the toolbar.
    @State private var lastTapPoint: CGPoint?

    /// The bounding box in *view* coordinates, used to position the box and mask overlay.
    @State private var boundingBox: CGRect?

    /// Side length of the square crop region sent to the model, in image pixels.
    private let cropSize: CGFloat = 200

    // MARK: - Body

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
            .navigationTitle("Mole Segmentation")
            .toolbar { toolbarContent }
            .alert("Error", isPresented: $showError) {
                Button("OK") { showError = false }
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
            .task { await loadSegmentor() }
        }
    }

    // MARK: - Image layer

    /// Renders the base image together with the bounding-box rectangle and mask overlay.
    ///
    /// The view is laid out with `scaledToFit`, so a `GeometryReader` is used to calculate
    /// the actual displayed image size and offset (letterbox) needed to convert between
    /// view coordinates and image-pixel coordinates.
    @ViewBuilder
    private func imageContent(image: UIImage) -> some View {
        GeometryReader { geometry in
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width, height: geometry.size.height)

                if let box = boundingBox {
                    Rectangle()
                        .stroke(Color.yellow, lineWidth: 2)
                        .frame(width: box.width, height: box.height)
                        .position(x: box.midX, y: box.midY)
                }

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

    /// Converts a tap in view coordinates to image-pixel coordinates, builds the
    /// bounding-box crop, runs segmentation, and updates the overlay.
    ///
    /// - Parameters:
    ///   - location: The tap position in the view's coordinate space.
    ///   - viewSize: The size of the `GeometryReader` frame containing the image.
    ///   - image: The full source image.
    private func handleTap(at location: CGPoint, in viewSize: CGSize, image: UIImage) {
        guard let segmentor, let cgImage = image.cgImage else { return }
        guard !isProcessing else { return }

        let pixelW = CGFloat(cgImage.width)
        let pixelH = CGFloat(cgImage.height)

        // Compute the sub-rect the aspect-fit image actually occupies inside viewSize.
        let imageAspect = pixelW / pixelH
        let viewAspect  = viewSize.width / viewSize.height

        let displayedSize: CGSize
        let letterboxOffset: CGPoint

        if imageAspect > viewAspect {
            // Image is wider than the view — fits to width, pillarboxed vertically.
            displayedSize    = CGSize(width: viewSize.width, height: viewSize.width / imageAspect)
            letterboxOffset  = CGPoint(x: 0, y: (viewSize.height - displayedSize.height) / 2)
        } else {
            // Image is taller than the view — fits to height, letterboxed horizontally.
            displayedSize    = CGSize(width: viewSize.height * imageAspect, height: viewSize.height)
            letterboxOffset  = CGPoint(x: (viewSize.width - displayedSize.width) / 2, y: 0)
        }

        // Map the tap from view space to image-pixel space.
        let tapPixel = CGPoint(
            x: max(0, min(pixelW, (location.x - letterboxOffset.x) / displayedSize.width  * pixelW)),
            y: max(0, min(pixelH, (location.y - letterboxOffset.y) / displayedSize.height * pixelH))
        )

        // Store the tap back in view coordinates for the toolbar debug readout.
        lastTapPoint = CGPoint(
            x: letterboxOffset.x + (tapPixel.x / pixelW) * displayedSize.width,
            y: letterboxOffset.y + (tapPixel.y / pixelH) * displayedSize.height
        )

        // Build a cropSize × cropSize bounding box in image-pixel space, clamped to the image.
        let halfCrop  = cropSize / 2
        let boxPixel  = CGRect(
            x:      max(0, min(pixelW - cropSize, tapPixel.x - halfCrop)),
            y:      max(0, min(pixelH - cropSize, tapPixel.y - halfCrop)),
            width:  min(cropSize, pixelW),
            height: min(cropSize, pixelH)
        )

        // Convert the bounding box to view coordinates so SwiftUI can position the overlay.
        boundingBox = CGRect(
            x:      letterboxOffset.x + (boxPixel.origin.x / pixelW) * displayedSize.width,
            y:      letterboxOffset.y + (boxPixel.origin.y / pixelH) * displayedSize.height,
            width:  (boxPixel.width  / pixelW) * displayedSize.width,
            height: (boxPixel.height / pixelH) * displayedSize.height
        )

        // The tap point relative to the crop, passed to the model as the prompt.
        let pointInCrop = CGPoint(x: tapPixel.x - boxPixel.origin.x,
                                  y: tapPixel.y - boxPixel.origin.y)

        Task {
            isProcessing = true
            do {
                guard let croppedCG = cgImage.cropping(to: boxPixel) else {
                    throw PipelineError.invalidImage
                }
                let croppedImage = UIImage(cgImage: croppedCG)
                let maskArray    = try await segmentor.segment(image: croppedImage,
                                                               point: pointInCrop,
                                                               modelSize: 1024)
                let maskImage    = try convertMaskToImage(maskArray, targetSize: boxPixel.size)

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

    /// Loads the Edge-SAM model asynchronously. Called once on view appear.
    private func loadSegmentor() async {
        do {
            segmentor = try await MoleSegmentor()
        } catch {
            errorMessage = "Failed to load model: \(error.localizedDescription)"
            showError = true
        }
    }

    /// Removes the current mask overlay, bounding box, and tap indicator,
    /// and clears the model's image-embedding cache.
    private func clearSegmentation() {
        cropMaskImage = nil
        lastTapPoint  = nil
        boundingBox   = nil
        segmentor?.clearCache()
    }

    // MARK: - Mask conversion

    /// Converts an `MLMultiArray` segmentation mask to a `UIImage`.
    ///
    /// Edge-SAM can return masks in several shapes — `[1,1,H,W]`, `[1,H,W]`, or `[H,W]`.
    /// Values above `0.5` are treated as foreground (white); the rest become black.
    /// The result is scaled to `targetSize` if the mask dimensions differ.
    ///
    /// - Parameters:
    ///   - maskArray: The raw mask output from the Edge-SAM decoder.
    ///   - targetSize: The size the returned image should match (typically the crop size).
    /// - Returns: A grayscale `UIImage` of the binary mask.
    /// - Throws: `PipelineError.renderFailed` if a `CGContext` cannot be created.
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
                let value: Float
                switch shape.count {
                case 4:  value = maskArray[[0, 0, y, x] as [NSNumber]].floatValue
                case 3:  value = maskArray[[0, y, x] as [NSNumber]].floatValue
                default: value = maskArray[[y, x] as [NSNumber]].floatValue
                }
                pixels[y * maskW + x] = value > 0.5 ? 255 : 0
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

    // MARK: - Supporting views

    /// Full-screen overlay shown while the pipeline is running.
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

    /// Shown in place of the image when `testImage` is `nil`.
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

    /// Navigation bar buttons and debug info.
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button("Clear") { clearSegmentation() }
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
}

// MARK: - Preview

#Preview {
    MoleSegmentationTestView()
}
