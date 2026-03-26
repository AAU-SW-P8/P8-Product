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

    // If this Person is deleted, all its instances are deleted
    @Relationship(deleteRule: .cascade, inverse: \Mole.person)
    var moles: [Mole] = []

    /// Creates a new Person record.
    /// - Parameters:
    ///   - name: Name of the person.
    ///   - createAt: Creation date of the person.
    init(
        name: String,
        createdAt: Date = Date()
    ) {
        self.name = name
        self.createdAt = createdAt
    }
}
