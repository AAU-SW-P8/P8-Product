//
//  MoleScan.swift
//  P8-Product
//
//  Created by Nicolaj Skjødt on 25/03/2026.
//

import Foundation
import SwiftData
import UIKit

@Model
final class MoleScan {
    @Attribute(.unique) var id: UUID = UUID()
    @Attribute(.externalStorage) var imageData: Data?
    
    var captureDate: Date
    var image: UIImage? {
        get {
            guard let imageData else { return nil }
            return UIImage(data: imageData)
        }
        set {
            imageData = newValue?.pngData()
        }
    }
    
    @Relationship(deleteRule: .cascade, inverse: \MoleInstance.moleScan)
    var instances: [MoleInstance] = []
    
    init
    (
        captureDate: Date = Date(),
        image: UIImage? = nil
    ) {
        self.captureDate = captureDate
        self.imageData = image?.pngData()
    }
}
