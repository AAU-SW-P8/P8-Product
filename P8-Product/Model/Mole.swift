//
//  Mole.swift
//  P8-Product
//
//  Created by Nicolaj Skjødt on 25/03/2026.
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
    
    init(
        name: String,
        bodyPart: String,
        isReminderActive: Bool,
        reminderFrequency: Frequency?,
        nextDueDate: Date?,
        person: Person? = nil,
    ) {
        self.name = name
        self.bodyPart = bodyPart
        self.isReminderActive = isReminderActive
        self.reminderFrequency = reminderFrequency
        self.nextDueDate = nextDueDate
        self.person = person
    }
}
