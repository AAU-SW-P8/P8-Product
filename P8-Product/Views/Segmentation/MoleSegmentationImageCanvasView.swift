import SwiftUI

struct MoleSegmentationImageCanvasView: View {
    let sourceImage: UIImage
    let maskOverlay: UIImage?
    let detectedBoxes: [CGRect]
    let onLongPressDetectedBox: (CGRect) -> Void

    @State private var currentZoom: Double = 0.0
    @State private var totalZoom: Double = 1.0
    @State private var currentPan: CGSize = .zero
    @State private var accumulatedPan: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            let displayedImage: UIImage = maskOverlay ?? sourceImage
            let imageAspect: Double = displayedImage.size.width / displayedImage.size.height
            let viewAspect: Double = geometry.size.width / geometry.size.height
            let viewportWidth: Double = imageAspect > viewAspect ? geometry.size.width : geometry.size.height * imageAspect
            let viewportHeight: Double = imageAspect > viewAspect ? geometry.size.width / imageAspect : geometry.size.height
            let viewportSize: CGSize = CGSize(width: viewportWidth, height: viewportHeight)

            let zoom: Double = clampedZoom(totalZoom + currentZoom)
            let pan: CGSize = clampedPan(currentPan, accumulatedPan, for: viewportSize, zoom: zoom)

            ZStack {
                ZStack {
                    if let mask: UIImage = maskOverlay {
                        Image(uiImage: mask)
                            .resizable()
                            .scaledToFill()
                            .frame(width: viewportWidth, height: viewportHeight)
                            .overlay {
                                let scaleX: Double = viewportWidth / mask.size.width
                                let scaleY: Double = viewportHeight / mask.size.height

                                ForEach(Array(detectedBoxes.enumerated()), id: \.offset) { _, box in
                                    let rect: CGRect = CGRect(
                                        x: box.minX * scaleX,
                                        y: box.minY * scaleY,
                                        width: box.width * scaleX,
                                        height: box.height * scaleY
                                    )

                                    Rectangle()
                                        .fill(Color.clear)
                                        .contentShape(Rectangle())
                                        .frame(width: rect.width, height: rect.height)
                                        .position(x: rect.midX, y: rect.midY)
                                        .onLongPressGesture {
                                            onLongPressDetectedBox(box)
                                        }
                                }
                            }
                    } else {
                        Image(uiImage: sourceImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: viewportWidth, height: viewportHeight)
                    }
                }
                .frame(width: viewportWidth, height: viewportHeight, alignment: .center)
                .scaleEffect(zoom, anchor: .center)
                .offset(pan)
                .clipped()
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        currentZoom = value - 1
                    }
                    .onEnded { _ in
                        totalZoom += currentZoom
                        currentZoom = 0

                        if totalZoom < 1.0 {
                            withAnimation {
                                totalZoom = 1.0
                                currentPan = .zero
                                accumulatedPan = .zero
                            }
                        } else if totalZoom > 5.0 {
                            withAnimation {
                                totalZoom = 5.0
                            }
                        }

                        accumulatedPan = clampedPan(.zero, accumulatedPan, for: viewportSize, zoom: clampedZoom(totalZoom))
                    }
            )
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        guard zoom > 1.0 else {
                            currentPan = .zero
                            return
                        }
                        currentPan = value.translation
                    }
                    .onEnded { _ in
                        guard zoom > 1.0 else {
                            currentPan = .zero
                            accumulatedPan = .zero
                            return
                        }

                        accumulatedPan = clampedPan(currentPan, accumulatedPan, for: viewportSize, zoom: zoom)
                        currentPan = .zero
                    }
            )
        }
    }

    private func clampedZoom(_ value: Double) -> Double {
        min(max(value, 1.0), 5.0)
    }

    private func clampedPan(_ current: CGSize, _ accumulated: CGSize, for size: CGSize, zoom: Double) -> CGSize {
        guard zoom > 1.0 else { return .zero }

        let maxX: CGFloat = (size.width * (zoom - 1.0)) / 2.0
        let maxY: CGFloat = (size.height * (zoom - 1.0)) / 2.0
        let proposedX: CGFloat = accumulated.width + current.width
        let proposedY: CGFloat = accumulated.height + current.height

        return CGSize(
            width: min(max(proposedX, -maxX), maxX),
            height: min(max(proposedY, -maxY), maxY)
        )
    }
}
