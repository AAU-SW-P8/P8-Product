//
// MockData.swift
// File only used for debugging
// Inserts mocked data into Application.
// P8-Product
//

import Foundation
import SwiftData
import UIKit

/// A utility structure used to populate the application with sample data.
/// This is primarily used for debugging, SwiftUI previews, and initial database seeding
@MainActor
struct MockData {
    /// Inserts a comprehensive set of sample people, moles, and scans into the provided context.
    /// - Parameter context: The ``ModelContext`` where the sample data will be persisted.
    static func insertSampleData(into context: ModelContext) {
        let calendar = Calendar.current
        let today = Date()

        // Create root Person objects
        let person1 = Person(name: "Alex", createdAt: daysAgo(30, from: today))
        let person2 = Person(name: "Jordan", createdAt: daysAgo(15, from: today))

        // Create Mole objects for Alex
        let alexLeftArmMole = Mole(
            name: "Left Arm Mole",
            bodyPart: "Left Arm",
            isReminderActive: true,
            reminderFrequency: .monthly,
            nextDueDate: calendar.date(byAdding: .month, value: 1, to: today),
            person: person1
        )

        let alexBackMole = Mole(
            name: "Back Mole",
            bodyPart: "Back",
            isReminderActive: false,
            reminderFrequency: nil,
            nextDueDate: nil,
            person: person1
        )

        // Create Mole object for Jordan
        let jordanFaceMole = Mole(
            name: "Face Mole",
            bodyPart: "Face",
            isReminderActive: true,
            reminderFrequency: .quarterly,
            nextDueDate: calendar.date(byAdding: .month, value: 3, to: today),
            person: person2
        )

        // Create Scans with placeholder image data
        let alexScan1 = MoleScan(
            captureDate: daysAgo(20, from: today),
            imageData: UIImage(systemName: "dot.circle.viewfinder")?.pngData()
        )
        let alexScan2 = MoleScan(
            captureDate: daysAgo(5, from: today),
            imageData: UIImage(systemName: "dot.circle.fill")?.pngData()
        )
        let alexScan3 = MoleScan(
            captureDate: daysAgo(10, from: today),
            imageData: UIImage(systemName: "circle.dotted")?.pngData()
        )
        let jordanScan1 = MoleScan(
            captureDate: daysAgo(2, from: today),
            imageData: UIImage(systemName: "face.smiling")?.pngData()
        )

        // Link everything together via MoleInstances
        let alexLeftArmInstance1 = MoleInstance(
            diameter: 4.2,
            area: 13.8,
            mole: alexLeftArmMole,
            moleScan: alexScan1
        )
        let alexLeftArmInstance2 = MoleInstance(
            diameter: 4.8,
            area: 15.4,
            mole: alexLeftArmMole,
            moleScan: alexScan2
        )
        let alexBackInstance = MoleInstance(
            diameter: 3.6,
            area: 10.1,
            mole: alexBackMole,
            moleScan: alexScan3
        )
        let jordanFaceInstance = MoleInstance(
            diameter: 2.9,
            area: 6.6,
            mole: jordanFaceMole,
            moleScan: jordanScan1
        )

        // Insert Objects
        context.insert(person1)
        context.insert(person2)
        context.insert(alexLeftArmMole)
        context.insert(alexBackMole)
        context.insert(jordanFaceMole)
        context.insert(alexScan1)
        context.insert(alexScan2)
        context.insert(alexScan3)
        context.insert(jordanScan1)
        context.insert(alexLeftArmInstance1)
        context.insert(alexLeftArmInstance2)
        context.insert(alexBackInstance)
        context.insert(jordanFaceInstance)
    }
    
    /// Helper to calculate a date in the past.
    /// - Parameters:
    ///   - days: Number of days to subtract.
    ///   - anchorDate: The starting date.
    /// - Returns: A calculated `Date` object.
    private static func daysAgo(_ days: Int, from anchorDate: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: anchorDate) ?? anchorDate
    }
}
