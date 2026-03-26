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
    
    // The segmentation result overlay
    @State private var maskOverlay: UIImage?
    
    // Loading state
    @State private var isProcessing = false
    
    // Error handling
    @State private var errorMessage: String?
    @State private var showError = false
    
    // The segmentor instance
    @State private var segmentor: MoleSegmentor?
    
    // Store the last tap point for debugging
    @State private var lastTapPoint: CGPoint?
    
    // Zoom and pan state
    @State private var currentScale: CGFloat = 1.0
    @State private var finalScale: CGFloat = 1.0
    @State private var currentOffset: CGSize = .zero
    @State private var finalOffset: CGSize = .zero
    
    var body: some View {
        NavigationView {
            ZStack {
                if let image = testImage {
                    GeometryReader { geometry in
                        ScrollView([.horizontal, .vertical], showsIndicators: true) {
                            ZStack {
                                // Original image
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                
                                // Segmentation mask overlay
                                if let mask = maskOverlay {
                                    Image(uiImage: mask)
                                        .resizable()
                                        .scaledToFit()
                                        .opacity(0.6)
                                        .blendMode(.multiply)
                                }
                                
                                // Tap point indicator
                                if let tapPoint = lastTapPoint {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 12, height: 12)
                                        .position(tapPoint)
                                }
                            }
                            .frame(
                                width: image.size.width * currentScale,
                                height: image.size.height * currentScale
                            )
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onEnded { value in
                                        handleTap(at: value.location, imageSize: image.size)
                                    }
                            )
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        currentScale = finalScale * value
                                    }
                                    .onEnded { value in
                                        finalScale = currentScale
                                        // Clamp scale between 1x and 10x
                                        finalScale = min(max(finalScale, 1.0), 10.0)
                                        currentScale = finalScale
                                    }
                            )
                        }
                    }
                    
                    // Loading overlay
                    if isProcessing {
                        ZStack {
                            Color.black.opacity(0.3)
                                .ignoresSafeArea()
                            
                            VStack(spacing: 16) {
                                ProgressView()
                                    .scaleEffect(1.5)
                                Text("Segmenting...")
                                    .foregroundColor(.white)
                                    .font(.headline)
                            }
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(12)
                        }
                    }
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "photo")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No test image found")
                            .font(.headline)
                        
                        Text("Add an image named 'test_mole_image' to Assets.xcassets")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                }
            }
            .navigationTitle("Mole Segmentation Test")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Clear Segmentation") {
                            clearSegmentation()
                        }
                        .disabled(maskOverlay == nil)
                        
                        Button("Reset Zoom") {
                            resetZoom()
                        }
                        .disabled(currentScale == 1.0)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Zoom: \(String(format: "%.1fx", currentScale))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let point = lastTapPoint {
                            Text("Tap: (\(Int(point.x)), \(Int(point.y)))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") {
                    showError = false
                }
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
            .task {
                await loadSegmentor()
            }
        }
    }
    
    // MARK: - Methods
    
    private func loadSegmentor() async {
        do {
            segmentor = try await MoleSegmentor()
        } catch {
            errorMessage = "Failed to load model: \(error.localizedDescription)"
            showError = true
        }
    }
    
    private func handleTap(at location: CGPoint, imageSize: CGSize) {
        guard let image = testImage, let segmentor = segmentor else { return }
        guard !isProcessing else { return } // Prevent multiple taps while processing
        
        // The location is already in the scaled image coordinate space
        // We need to convert it back to the original image coordinates
        let imagePoint = CGPoint(
            x: location.x / currentScale,
            y: location.y / currentScale
        )
        
        // Clamp to image bounds
        let clampedPoint = CGPoint(
            x: max(0, min(imageSize.width, imagePoint.x)),
            y: max(0, min(imageSize.height, imagePoint.y))
        )
        
        // Store for display (in scaled coordinates for the red dot)
        lastTapPoint = location
        
        // Run segmentation with the original image coordinates
        Task {
            isProcessing = true
            
            do {
                let maskArray = try await segmentor.segment(
                    image: image,
                    point: clampedPoint,
                    modelSize: 1024
                )
                
                // Convert mask to image
                let maskImage = try convertMaskToImage(maskArray, targetSize: imageSize)
                
                await MainActor.run {
                    maskOverlay = maskImage
                    isProcessing = false
                }
                
            } catch {
                await MainActor.run {
                    errorMessage = "Segmentation failed: \(error.localizedDescription)"
                    showError = true
                    isProcessing = false
                }
            }
        }
    }
    
    private func resetZoom() {
        withAnimation(.spring()) {
            currentScale = 1.0
            finalScale = 1.0
            currentOffset = .zero
            finalOffset = .zero
        }
    }
    
    private func clearSegmentation() {
        maskOverlay = nil
        lastTapPoint = nil
        segmentor?.clearCache()
    }
    
    // MARK: - Mask Conversion
    
    private func convertMaskToImage(_ maskArray: MLMultiArray, targetSize: CGSize) throws -> UIImage {
        // SAM output can be [1, 1, H, W], [1, H, W], or [H, W]
        let shape = maskArray.shape.map { $0.intValue }
        
        // Determine mask dimensions
        let maskHeight: Int
        let maskWidth: Int
        
        if shape.count == 4 {
            // [batch, channels, height, width]
            maskHeight = shape[2]
            maskWidth = shape[3]
        } else if shape.count == 3 {
            // [batch, height, width]
            maskHeight = shape[1]
            maskWidth = shape[2]
        } else if shape.count == 2 {
            // [height, width]
            maskHeight = shape[0]
            maskWidth = shape[1]
        } else {
            throw PipelineError.renderFailed
        }
        
        // Create a grayscale image from the mask
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let bitmapInfo = CGImageAlphaInfo.none.rawValue
        
        guard let context = CGContext(
            data: nil,
            width: maskWidth,
            height: maskHeight,
            bitsPerComponent: 8,
            bytesPerRow: maskWidth,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            throw PipelineError.renderFailed
        }
        
        guard let data = context.data else {
            throw PipelineError.renderFailed
        }
        
        let pixelBuffer = data.assumingMemoryBound(to: UInt8.self)
        
        // Fill pixel buffer - convert mask values to 0 or 255
        for y in 0..<maskHeight {
            for x in 0..<maskWidth {
                let index = y * maskWidth + x
                
                // Get mask value - adjust indexing based on actual output shape
                let maskValue: Float
                if shape.count == 4 {
                    // [batch, channels, height, width]
                    maskValue = maskArray[[0, 0, y, x] as [NSNumber]].floatValue
                } else if shape.count == 3 {
                    // [batch, height, width]
                    maskValue = maskArray[[0, y, x] as [NSNumber]].floatValue
                } else {
                    // [height, width]
                    maskValue = maskArray[[y, x] as [NSNumber]].floatValue
                }
                
                // Convert to binary mask (threshold at 0.5)
                pixelBuffer[index] = maskValue > 0.5 ? 255 : 0
            }
        }
        
        guard let cgImage = context.makeImage() else {
            throw PipelineError.renderFailed
        }
        
        // Scale to target size if needed
        let maskImage = UIImage(cgImage: cgImage)
        
        if maskImage.size != targetSize {
            return resizeImage(maskImage, to: targetSize)
        }
        
        return maskImage
    }
    
    private func resizeImage(_ image: UIImage, to size: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: size))
        let resized = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        return resized
    }
}

// MARK: - Preview

#Preview {
    MoleSegmentationTestView()
}
