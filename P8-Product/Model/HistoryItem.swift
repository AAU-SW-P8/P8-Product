import Foundation
import SwiftData

@Model
final class HistoryItem {
    var name: String
    var timestamp: Date
    @Attribute(.externalStorage) var imageData: Data?
    var isFlagged: Bool = false
    var person: Person?
    
    init(name: String, timestamp: Date = Date(), imageData: Data? = nil, isFlagged: Bool = false, person: Person? = nil) {
        self.name = name
        self.timestamp = timestamp
        self.imageData = imageData
        self.isFlagged = isFlagged
        self.person = person
    }
}
