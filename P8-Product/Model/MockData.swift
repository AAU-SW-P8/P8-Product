//
// MockData.swift
// File only used for debugging
// Inserts mocked data into Application.
// P8-Product
//

import Foundation
import SwiftData
import SwiftUI

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
        let person3 = Person(name: "Taylor", createdAt: daysAgo(5, from: today))

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
            captureDate: daysAgo(100, from: today),
            imageData: UIImage(systemName: "1.circle.fill")?.pngData()
        )
        let alexScan2 = MoleScan(
            captureDate: daysAgo(90, from: today),
            imageData: UIImage(systemName: "2.circle.fill")?.pngData()
        )
        let alexScan3 = MoleScan(
            captureDate: daysAgo(80, from: today),
            imageData: UIImage(systemName: "3.circle.fill")?.pngData()
        )

        let alexScan4 = MoleScan(
            captureDate: daysAgo(70, from: today),
            imageData: UIImage(systemName: "4.circle.fill")?.pngData()
        )
        
        let alexScan5 = MoleScan(
            captureDate: daysAgo(60, from: today),
            imageData: UIImage(systemName: "5.circle.fill")?.pngData()
        )
        
        let alexScan6 = MoleScan(
            captureDate: daysAgo(50, from: today),
            imageData: UIImage(systemName: "6.circle.fill")?.pngData()
        )

        let alexScan7 = MoleScan(
            captureDate: daysAgo(40, from: today),
            imageData: UIImage(systemName: "7.circle.fill")?.pngData()
        )
        
        let jordanScan1 = MoleScan(
            captureDate: daysAgo(30, from: today),
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
    
        let alexLeftArmInstance3 = MoleInstance(
            diameter: 5.0,
            area: 16.0,
            mole: alexLeftArmMole,
            moleScan: alexScan3
        )
        
        let alexLeftArmInstance4 = MoleInstance(
            diameter: 5.0,
            area: 16.0,
            mole: alexLeftArmMole,
            moleScan: alexScan4
        )
        
        let alexLeftArmInstance5 = MoleInstance(
            diameter: 5.0,
            area: 16.0,
            mole: alexLeftArmMole,
            moleScan: alexScan5
        )
        
        let alexLeftArmInstance6 = MoleInstance(
            diameter: 5.0,
            area: 16.0,
            mole: alexLeftArmMole,
            moleScan: alexScan6
        )
        
        
        let alexLeftArmInstance7 = MoleInstance(
            diameter: 5.7,
            area: 18.9,
            mole: alexLeftArmMole,
            moleScan: alexScan7
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
        context.insert(person3)
        context.insert(alexLeftArmMole)
        context.insert(alexBackMole)
        context.insert(jordanFaceMole)
        context.insert(alexScan1)
        context.insert(alexScan2)
        context.insert(alexScan3)
        context.insert(alexScan4)
        context.insert(alexScan5)
        context.insert(alexScan6)
        context.insert(alexScan7)
        context.insert(jordanScan1)
        context.insert(alexLeftArmInstance1)
        context.insert(alexLeftArmInstance2)
        context.insert(alexLeftArmInstance3)
        context.insert(alexLeftArmInstance4)
        context.insert(alexLeftArmInstance5)
        context.insert(alexLeftArmInstance6)
        context.insert(alexLeftArmInstance7)
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
