//
// MoleScan.swift
// P8-Product
//

import Foundation
import SwiftData

@Model
final class MoleScan {
    @Attribute(.unique) var id: UUID = UUID()
    @Attribute(.externalStorage) var imageData: Data?

    var captureDate: Date = Date()

    var diameter: Float
    var area: Float

    // The inverse relationships back to the mole the scan belongs to
    var mole: Mole?

    /// Creates a new MoleScan record.
    /// - Parameters:
    ///   - captureDate: The date of when the picture was taken.
    ///   - imageData: The image data.
    init
    (
        captureDate: Date = Date(),
        imageData: Data? = nil,
        diameter: Float = 0.0,
        area: Float = 0.0,
        mole: Mole? = nil
    ) {
        self.captureDate = captureDate
        self.imageData = imageData
        self.diameter = diameter
        self.area = area
        self.mole = mole
    }
}
