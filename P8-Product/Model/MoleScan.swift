//
// MoleScan.swift
// P8-Product
//

import Foundation
import SwiftData

/// A SwiftData model representing a single scan of a mole.
@Model
final class MoleScan {
    /// Unique identifier for this scan.
    @Attribute(.unique) var id: UUID = UUID()
    /// JPEG image data stored externally on disk.
    @Attribute(.externalStorage) var imageData: Data?
    /// The date the scan image was captured.
    var captureDate: Date = Date()
    /// The measured diameter of the mole in millimetres.
    var diameter: Float
    /// The measured area of the mole in square millimetres.
    var area: Float
    /// The mole this scan belongs to.
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
