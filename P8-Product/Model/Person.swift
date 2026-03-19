//
// Person.swift
// P8-Product
//

import Foundation
import SwiftData

@Model
final class Person {
    var name: String
    var timestamp: Date
    @Relationship(deleteRule: .cascade, inverse: \HistoryItem.person) var historyItems: [HistoryItem] = []
    
    init(name: String, timestamp: Date = Date()) {
        self.name = name
        self.timestamp = timestamp
    }
}
