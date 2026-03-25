//
//  Mole.swift
//  P8-Product
//
//  Created by Nicolaj Skjødt on 25/03/2026.
//

import Foundation
import SwiftData
import SwiftUI
import UIKit

enum Frequency: String {
    case monthly, quarterly, yearly
}

@Model
final class Mole {
    @Attribute(.unique) var id: UUID
    var person: Person?
    var name: String
    var bodyPart: String
    var isReminderActive: Bool = false
    var reminderFrequency: Frequency?
    var nextDueDate: Date?
    
    init(
        id: UUID = UUID(),
        person: Person? = nil,
        name: String,
        bodyPart: String,
        isReminderActive: Bool = false,
        reminderFrequency: Frequency,
        nextDueDate: Date = Date()
    ) {
        self.id = id
        self.person = person
        self.name = name
        self.bodyPart = bodyPart
        self.isReminderActive = isReminderActive
        self.reminderFrequency = reminderFrequency
        self.nextDueDate = nextDueDate
    }
}
