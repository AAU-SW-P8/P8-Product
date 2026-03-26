import Foundation
import SwiftData
import UIKit

@MainActor
struct MockData {
    static func insertSampleData(into context: ModelContext) {
        let calendar = Calendar.current
        let today = Date()

        func date(daysAgo: Int) -> Date {
            calendar.date(byAdding: .day, value: -daysAgo, to: today) ?? today
        }

        let person1 = Person(name: "Alex", createdAt: date(daysAgo: 30))
        let person2 = Person(name: "Jordan", createdAt: date(daysAgo: 15))

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

        let jordanFaceMole = Mole(
            name: "Face Mole",
            bodyPart: "Face",
            isReminderActive: true,
            reminderFrequency: .quarterly,
            nextDueDate: calendar.date(byAdding: .month, value: 3, to: today),
            person: person2
        )

        let alexScan1 = MoleScan(
            captureDate: date(daysAgo: 20),
            imageData: UIImage(systemName: "dot.circle.viewfinder")?.pngData()
        )
        let alexScan2 = MoleScan(
            captureDate: date(daysAgo: 5),
            imageData: UIImage(systemName: "dot.circle.fill")?.pngData()
        )
        let alexScan3 = MoleScan(
            captureDate: date(daysAgo: 10),
            imageData: UIImage(systemName: "circle.dotted")?.pngData()
        )
        let jordanScan1 = MoleScan(
            captureDate: date(daysAgo: 2),
            imageData: UIImage(systemName: "face.smiling")?.pngData()
        )

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
}
