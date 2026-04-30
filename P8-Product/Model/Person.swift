//
// Person.swift
// P8-Product
//

import Foundation
import SwiftData

/// A SwiftData model representing a person who owns one or more moles.
@Model
final class Person {
    /// Unique identifier for the person.
    @Attribute(.unique) var id: UUID = UUID()
    /// The display name of the person.
    var name: String
    /// The date the person record was created.
    var createdAt: Date
    /// The default reminder frequency string (e.g., "Weekly", "Monthly", "Quarterly").
    var defaultReminderFrequency: String
    /// Whether the default reminder is enabled for this person.
    var defaultReminderEnabled: Bool
    /// All moles belonging to this person; deleted automatically when the person is deleted.
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
