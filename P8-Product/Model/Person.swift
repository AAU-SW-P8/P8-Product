//
// Person.swift
// P8-Product
//

import Foundation
import SwiftData

@Model
final class Person {
    @Attribute(.unique) var id: UUID
    var name: String
    @Relationship(deleteRule: .cascade, inverse: \HistoryItem.person) var historyItems: [HistoryItem] = []
    @Relationship(deleteRule: .cascade, inverse: \Mole.person) var moles: [Mole] = []
    init(
        id: UUID = UUID(),
        name: String
    ) {
        self.id = id
        self.name = name
    }
}
