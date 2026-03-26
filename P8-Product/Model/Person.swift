//
// Person.swift
// P8-Product
//

import Foundation
import SwiftData

@Model
final class Person {
    @Attribute(.unique) var id: UUID = UUID()
    var name: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Mole.person)
    var moles: [Mole] = []

    init(
        name: String,
        createdAt: Date = Date()
    ) {
        self.name = name
        self.createdAt = createdAt
    }
}
