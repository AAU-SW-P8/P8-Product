//
//  SegmentationRenderer.swift
//  P8-Product
//
//  Pure presentation: takes the original photo plus the decoder's mask
//  tensor and a list of accepted detections, and returns an annotated image
//  with colored mask overlays, bounding boxes, and per-detection labels.
//
//  This file deliberately knows nothing about CoreML beyond the shape of
//  `MLMultiArray` it indexes into — no model loading, no preprocessing.
//

import CoreGraphics
import CoreML
import UIKit

/// Renders mole segmentation results onto a base image.
final class SegmentationRenderer {

  /// Side length of the decoder's mask tensor (288×288 logits per detection).
  static let maskSize = 288

  /// Distinct colors used to tint successive detections (RGB, 0–255).
  private static let palette: [(UInt8, UInt8, UInt8)] = [
    (230, 25, 75),  // red
    (60, 180, 75),  // green
    (0, 130, 200),  // blue
    (255, 225, 25),  // yellow
    (245, 130, 48),  // orange
    (145, 30, 180),  // purple
    (70, 240, 240),  // cyan
    (240, 50, 230),  // magenta
    (210, 245, 60),  // lime
    (250, 190, 212),  // pink
  ]

  /// Peak alpha applied to a fully-confident mask pixel.
  private static let maskAlphaMax: Float = SegmentationRendererValues.maskAlphaMax

  /// Renders an annotated copy of `baseImage` plus the pixel-space bounding
  /// boxes derived from each detection's mask.
  ///
  /// - Parameters:
  ///   - baseImage: The original (full-resolution) photo to draw onto.
  ///   - detections: Detections kept after confidence filtering and NMS.
  ///   - masks: Decoder mask tensor `[1, N, maskSize, maskSize]` of logits.
  /// - Returns: The annotated image and the bounding boxes (in `baseImage`'s
  ///   pixel coordinate space), or `nil` if the graphics context could not
  ///   be created.
  func renderOverlay(
    on baseImage: UIImage,
    detections: [RawDetection],
    masks: MLMultiArray
  ) -> (UIImage, [CGRect])? {
    let imageSize = baseImage.size

    UIGraphicsBeginImageContextWithOptions(imageSize, false, 0.0)
    guard let ctx = UIGraphicsGetCurrentContext() else { return nil }
    defer { UIGraphicsEndImageContext() }

    baseImage.draw(in: CGRect(origin: .zero, size: imageSize))
    ctx.interpolationQuality = .high

    var pixelBoxes: [CGRect] = []

    for (detId, det) in detections.enumerated() {
      let color = Self.palette[detId % Self.palette.count]

      // Build a small tinted RGBA buffer for this detection and let
      // UIKit upscale it with high-quality interpolation (smoother than
      // pixel-doubling 288→full-res ourselves).
      let (maskCG, maskBox) = buildTintedMaskImage(
        from: masks,
        detectionIndex: det.index,
        color: color
      )

      if let maskCG = maskCG {
        UIImage(cgImage: maskCG).draw(
          in: CGRect(origin: .zero, size: imageSize),
          blendMode: .normal,
          alpha: 1.0
        )
      }

      guard let maskBox = maskBox else { continue }

      let scaleX = imageSize.width / CGFloat(Self.maskSize)
      let scaleY = imageSize.height / CGFloat(Self.maskSize)
      let pixelBox = CGRect(
        x: maskBox.minX * scaleX,
        y: maskBox.minY * scaleY,
        width: maskBox.width * scaleX,
        height: maskBox.height * scaleY
      )
      pixelBoxes.append(pixelBox)

      drawBoundingBox(pixelBox, color: color, imageSize: imageSize, in: ctx)
      drawLabel(
        forDetectionId: detId, prob: det.prob, at: pixelBox, color: color, imageSize: imageSize)
    }

    return UIGraphicsGetImageFromCurrentImageContext().map { ($0, pixelBoxes) }
  }

  /// Builds a tinted RGBA `CGImage` for a single detection's mask, plus the
  /// detection's tight bounding box in *mask coordinates* (or `nil` if the
  /// mask is empty above the logit-zero threshold).
  ///
  /// The mask logit is squashed through a sigmoid so the edge fades out
  /// smoothly instead of stepping at the threshold.
  private func buildTintedMaskImage(
    from masks: MLMultiArray,
    detectionIndex: Int,
    color: (UInt8, UInt8, UInt8)
  ) -> (CGImage?, CGRect?) {
    let maskW = Self.maskSize
    let maskH = Self.maskSize
    let bytesPerRow = maskW * 4

    let rByte = Float(color.0)
    let gByte = Float(color.1)
    let bByte = Float(color.2)

    var rgbaBuffer = [UInt8](repeating: 0, count: maskW * maskH * 4)
    var minX = maskW
    var minY = maskH
    var maxX = 0
    var maxY = 0
    var anyPixel = false

    for y in 0..<maskH {
      for x in 0..<maskW {
        let logit = masks[[0, detectionIndex, y, x] as [NSNumber]].floatValue
        // Sigmoid → soft [0,1] probability for smooth edge falloff.
        let prob = 1.0 / (1.0 + exp(-logit))
        let alpha = prob * Self.maskAlphaMax

        // Premultiplied RGB (required by .premultipliedLast).
        let offset = (y * maskW + x) * 4
        rgbaBuffer[offset] = UInt8(rByte * alpha)
        rgbaBuffer[offset + 1] = UInt8(gByte * alpha)
        rgbaBuffer[offset + 2] = UInt8(bByte * alpha)
        rgbaBuffer[offset + 3] = UInt8(max(0, min(255, alpha * 255)))

        if logit > 0 {
          minX = min(minX, x)
          minY = min(minY, y)
          maxX = max(maxX, x)
          maxY = max(maxY, y)
          anyPixel = true
        }
      }
    }

    let cgImage = makeCGImage(
      from: rgbaBuffer, width: maskW, height: maskH, bytesPerRow: bytesPerRow)
    let maskBox: CGRect? =
      anyPixel
      ? CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
      : nil
    return (cgImage, maskBox)
  }

  /// Wraps a tinted RGBA byte buffer in a `CGImage` so UIKit can scale it.
  private func makeCGImage(from buffer: [UInt8], width: Int, height: Int, bytesPerRow: Int)
    -> CGImage? {
    let data = Data(buffer)
    guard let provider = CGDataProvider(data: data as CFData) else { return nil }
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
    return CGImage(
      width: width,
      height: height,
      bitsPerComponent: 8,
      bitsPerPixel: 32,
      bytesPerRow: bytesPerRow,
      space: colorSpace,
      bitmapInfo: bitmapInfo,
      provider: provider,
      decode: nil,
      shouldInterpolate: true,
      intent: .defaultIntent
    )
  }

  /// Renders a mask-only image (no base photo) where alpha encodes mole
  /// probability. Used by the Calculator to identify which pixels belong
  /// to detected moles.
  ///
  /// - Parameters:
  ///   - imageSize: The target image size (should match the camera image).
  ///   - detections: Detections kept after confidence filtering and NMS.
  ///   - masks: Decoder mask tensor `[1, N, maskSize, maskSize]` of logits.
  /// - Returns: A UIImage at scale 1.0 where only mole pixels have alpha > 0.
  func renderMaskOnly(
    imageSize: CGSize,
    detections: [RawDetection],
    masks: MLMultiArray
  ) -> UIImage? {
    // Scale 1.0 so pixel dimensions match the camera image exactly
    // (camera intrinsics are calibrated to those pixel dimensions).
    UIGraphicsBeginImageContextWithOptions(imageSize, false, 1.0)
    guard let ctx = UIGraphicsGetCurrentContext() else { return nil }
    defer { UIGraphicsEndImageContext() }

    // Keep a hard edge in the measurement mask to avoid area drift from
    // interpolation blur when upscaling the decoder's 288x288 output.
    ctx.interpolationQuality = .none

    for (detId, det) in detections.enumerated() {
      let color = Self.palette[detId % Self.palette.count]
      let (maskCG, _) = buildTintedMaskImage(
        from: masks,
        detectionIndex: det.index,
        color: color
      )
      if let maskCG = maskCG {
        UIImage(cgImage: maskCG).draw(
          in: CGRect(origin: .zero, size: imageSize),
          blendMode: .normal,
          alpha: 1.0
        )
      }
    }

    return UIGraphicsGetImageFromCurrentImageContext()
  }

  /// Strokes a colored bounding box. Line width scales with the source
  /// image so boxes don't look chunky on high-resolution photos.
  private func drawBoundingBox(
    _ rect: CGRect, color: (UInt8, UInt8, UInt8), imageSize: CGSize, in ctx: CGContext
  ) {
    ctx.setStrokeColor(
      red: CGFloat(color.0) / 255.0,
      green: CGFloat(color.1) / 255.0,
      blue: CGFloat(color.2) / 255.0,
      alpha: 1.0
    )
    ctx.setLineWidth(max(imageSize.width / 2000, 1.0))
    ctx.stroke(rect)
  }

  /// Draws an `id=…, p=…` label above (or just inside) the bounding box.
  /// Font size scales with the source image so labels stay readable on
  /// high-resolution photos.
  private func drawLabel(
    forDetectionId detId: Int,
    prob: Float,
    at boxRect: CGRect,
    color: (UInt8, UInt8, UInt8),
    imageSize: CGSize
  ) {
    let label = String(format: "id=%d, p=%.2f", detId, prob)
    let attrs: [NSAttributedString.Key: Any] = [
      .font: UIFont.boldSystemFont(ofSize: max(imageSize.width / 60, 10)),
      .foregroundColor: UIColor(
        red: CGFloat(color.0) / 255.0,
        green: CGFloat(color.1) / 255.0,
        blue: CGFloat(color.2) / 255.0,
        alpha: 1.0
      ),
      .backgroundColor: UIColor(white: 1.0, alpha: 0.75),
    ]
    let labelSize = (label as NSString).size(withAttributes: attrs)
    let labelOrigin = CGPoint(
      x: boxRect.minX,
      y: max(boxRect.minY - labelSize.height - 5, 0)
    )
    (label as NSString).draw(at: labelOrigin, withAttributes: attrs)
  }
}
