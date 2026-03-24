//
// Person.swift
// P8-Product
//

import Foundation
import SwiftData
import SwiftUI
import UIKit

@Model
final class HistoryItem {
    var name: String
    var timestamp: Date
    @Attribute(.externalStorage) var imageData: Data?
    var isFlagged: Bool = false
    var person: Person?
    
    var image: UIImage? {
        get {
            guard let imageData else { return nil }
            return UIImage(data: imageData)
        }
        set {
            imageData = newValue?.pngData()
        }
    }
    
    init(name: String, timestamp: Date = Date(), image: UIImage? = nil, isFlagged: Bool = false, person: Person? = nil) {
        self.name = name
        self.timestamp = timestamp
        self.imageData = image?.pngData()
        self.isFlagged = isFlagged
        self.person = person
    }
}
