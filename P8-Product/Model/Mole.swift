//
// Mole.swift
// P8-Product
//

import Foundation
import SwiftData

enum Frequency: String, Codable {
    case monthly, quarterly, yearly
}

@Model
final class Mole {
    @Attribute(.unique) var id: UUID = UUID()
    
    var name: String
    var bodyPart: String
    var isReminderActive: Bool
    var reminderFrequency: Frequency?
    var nextDueDate: Date?
    
    // The inverse relationships back to the parents
    var person: Person?
    
    // If this Mole is deleted, all its instances are deleted
    @Relationship(deleteRule: .cascade, inverse: \MoleInstance.mole)
    var instances: [MoleInstance] = []
    
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
        followDefault: Bool = true,
        reminderFrequency: Frequency?,
        nextDueDate: Date?,
        person: Person? = nil,
    ) {
        self.name = name
        self.bodyPart = bodyPart
        self.isReminderActive = isReminderActive
        self.followDefault = followDefault
        self.reminderFrequency = reminderFrequency
        self.nextDueDate = nextDueDate
        self.person = person
    }
}
