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
    
    // If a MoleScan is deleted, all its instances are deleted
    @Relationship(deleteRule: .cascade, inverse: \MoleInstance.moleScan)
    var instances: [MoleInstance] = []
    
    /// Creates a new MoleScan record.
    /// - Parameters:
    ///   - captureDate: The date of when the picture was taken.
    ///   - imageData: The image data.
    init
    (
        captureDate: Date = Date(),
        imageData: Data? = nil
    ) {
        self.captureDate = captureDate
        self.imageData = imageData
    }
}
