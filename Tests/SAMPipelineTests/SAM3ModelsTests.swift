import CoreML
import Testing
@testable import P8_Product

@Suite("SAM3Models")
/// Tests for `SAM3Models`, verifying that all three Core ML models load successfully from the app bundle.
struct SAM3ModelsTests {

    @Test @MainActor 
    func load_returnsAllThreeModels() async throws {
        // The test host (the app bundle) includes the ML models,
        // so loading should succeed and return all three models.
        let models = try await SAM3Models.load()
        #expect(models.visionEncoder.modelDescription.inputDescriptionsByName.count > 0)
        #expect(models.textEncoder.modelDescription.inputDescriptionsByName.count > 0)
        #expect(models.decoder.modelDescription.inputDescriptionsByName.count > 0)
    }
}
