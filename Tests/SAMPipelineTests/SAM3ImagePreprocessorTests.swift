import CoreML
import Testing
import UIKit
@testable import P8_Product

@Suite("SAM3ImagePreprocessor")
struct SAM3ImagePreprocessorTests {

    @Test func inputSize_is1008() {
        #expect(SAM3ImagePreprocessor.inputSize == 1008)
    }

    @Test func preprocess_validImage_returnsCorrectShapeAndType() throws {
        let image = makeTestImage(width: 10, height: 10, color: .red)
        let preprocessor = SAM3ImagePreprocessor()
        let tensor = try preprocessor.preprocess(image)

        #expect(tensor.shape == [1, 3, 1008, 1008] as [NSNumber])
        #expect(tensor.dataType == .float16)
    }

    @Test func preprocess_noCGImage_throwsInvalidImage() throws {
        // UIImage backed by CIImage has no cgImage.
        let ciOnly = UIImage(ciImage: CIImage.empty())
        let preprocessor = SAM3ImagePreprocessor()

        #expect(throws: PipelineError.self) {
            try preprocessor.preprocess(ciOnly)
        }
    }

    @Test func preprocess_pureWhite_normalizesToOne() throws {
        let image = makeTestImage(width: 64, height: 64, color: .white)
        let preprocessor = SAM3ImagePreprocessor()
        let tensor = try preprocessor.preprocess(image)

        // White (255,255,255) -> 255/127.5 - 1 = 1.0 for all channels.
        // Check a center pixel to avoid edge interpolation artifacts.
        let mid = SAM3ImagePreprocessor.inputSize / 2
        let hw = SAM3ImagePreprocessor.inputSize * SAM3ImagePreprocessor.inputSize
        let ptr = tensor.dataPointer.bindMemory(
            to: Float16.self,
            capacity: 3 * hw
        )

        let spatial = mid * SAM3ImagePreprocessor.inputSize + mid
        let r = Float(ptr[0 * hw + spatial])
        let g = Float(ptr[1 * hw + spatial])
        let b = Float(ptr[2 * hw + spatial])

        #expect(abs(r - 1.0) < 0.02)
        #expect(abs(g - 1.0) < 0.02)
        #expect(abs(b - 1.0) < 0.02)
    }

    // MARK: - Helpers

    private func makeTestImage(width: Int, height: Int, color: UIColor) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        return renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }
}
