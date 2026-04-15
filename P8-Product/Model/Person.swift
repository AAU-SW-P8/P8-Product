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
    var defaultReminderFrequency: String
    var defaultReminderEnabled: Bool

    // If this Person is deleted, all its instances are deleted
    @Relationship(deleteRule: .cascade, inverse: \Mole.person)
    var moles: [Mole] = []

    /// Creates a new Person record.
    /// - Parameters:
    ///   - name: Name of the person.
    ///   - createAt: Creation date of the person.
    ///   - defaultReminderFrequency: The default reminder frequency for the person.
    ///   - defaultReminderEnabled: Whether the default reminder is enabled.
    init(
        name: String,
        createdAt: Date = Date(),
        defaultReminderFrequency: String = "Weekly",
        defaultReminderEnabled: Bool = true
    ) {
        self.name = name
        self.createdAt = createdAt
        self.defaultReminderFrequency = defaultReminderFrequency
        self.defaultReminderEnabled = defaultReminderEnabled
    }
}
