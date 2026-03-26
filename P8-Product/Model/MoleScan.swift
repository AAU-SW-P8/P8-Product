//
//  MoleScan.swift
//  P8-Product
//

import Foundation
import SwiftData

@Model
final class MoleScan {
    @Attribute(.unique) var id: UUID = UUID()
    @Attribute(.externalStorage) var imageData: Data?
    
    var captureDate: Date = Date()
    
    @Relationship(deleteRule: .cascade, inverse: \MoleInstance.moleScan)
    var instances: [MoleInstance] = []
    
    init
    (
        captureDate: Date = Date(),
        imageData: Data? = nil
    ) {
        self.captureDate = captureDate
        self.imageData = imageData
    }
}
