//
// Mole.swift
// P8-Product
//

import Foundation
import SwiftData

/// Represents how often a mole should be checked.
enum Frequency: String, Codable {
    /// Check the mole once per week.
    case weekly
    /// Check the mole once per month.
    case monthly
    /// Check the mole once every three months.
    case quarterly
}

/// A SwiftData model representing a single mole belonging to a person.
@Model
final class Mole {
    /// Unique identifier for the mole.
    @Attribute(.unique) var id: UUID = UUID()
    /// Display name for the mole.
    var name: String
    /// The body area where the mole is located.
    var bodyPart: String
    /// Whether reminders are active for this mole.
    var isReminderActive: Bool
    /// When `true`, the mole inherits the person's default reminder-enabled setting.
    var followDefaultReminderEnabled: Bool?
    /// When `true`, the mole inherits the person's default reminder frequency.
    var followDefault: Bool?
    /// The per-mole reminder frequency override; `nil` means follow the default.
    var reminderFrequency: Frequency?
    /// The date by which the next scan should be taken.
    var nextDueDate: Date?
    /// The person this mole belongs to.
    var person: Person?
    /// All scans taken of this mole; deleted automatically when the mole is deleted.
    @Relationship(deleteRule: .cascade, inverse: \MoleScan.mole)
    var scans: [MoleScan] = []
    
    /// Creates a new Mole record.
    /// - Parameters:
    ///   - name: The display name for the mole.
    ///   - bodyPart: The body part where the mole is located.
    ///   - isReminderActive: Whether reminders are currently enabled.
    ///   - followDefault: Whether to follow the default reminder frequency (defaults to `true`).
    ///   - reminderFrequency: How often the mole should be checked.
    ///   - nextDueDate: The date the next scan is expected.
    ///   - person: The owner of the mole (defaults to `nil`).
    init(
        name: String,
        bodyPart: String,
        isReminderActive: Bool,
        followDefaultReminderEnabled: Bool = true,
        followDefault: Bool = true,
        reminderFrequency: Frequency?,
        nextDueDate: Date?,
        person: Person? = nil,
    ) {
        self.name = name
        self.bodyPart = bodyPart
        self.isReminderActive = isReminderActive
        self.followDefaultReminderEnabled = followDefaultReminderEnabled
        self.followDefault = followDefault
        self.reminderFrequency = reminderFrequency
        self.nextDueDate = nextDueDate
        self.person = person
    }
}
