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
struct MockDataUsabilityTest {
  /// Inserts a comprehensive set of sample people, moles, and scans into the provided context.
  /// - Parameter context: The ``ModelContext`` where the sample data will be persisted.
  static func insertSampleData(into context: ModelContext) {
    let calendar = Calendar.current
    let today = Date()

    // Create root Person objects
    let person1 = Person(name: "Adam", createdAt: daysAgo(30, from: today))
    
    // Create Mole objects for Alex
    let adamBackMole = Mole(
      name: "Skulderblad",
      bodyPart: "Back",
      isReminderActive: true,
      reminderFrequency: .monthly,
      nextDueDate: calendar.date(byAdding: .month, value: 1, to: today),
      person: person1
    )
      
    let adamBackMole2 = Mole(
      name: "Lænd buksekant",
      bodyPart: "Back",
      isReminderActive: true,
      reminderFrequency: .quarterly,
      nextDueDate: calendar.date(byAdding: .month, value: 1, to: today),
      person: person1
    )
      
    let adamBackMole3 = Mole(
      name: "Stor venstre lænd",
      bodyPart: "Back",
      isReminderActive: true,
      reminderFrequency: .monthly,
      nextDueDate: calendar.date(byAdding: .month, value: 1, to: today),
      person: person1
    )
    
    let adamHånd = Mole(
      name: "Håndflade",
      bodyPart: "Right Hand",
      isReminderActive: true,
      reminderFrequency: .monthly,
      nextDueDate: calendar.date(byAdding: .month, value: 1, to: today),
      person: person1
    )
      
    let adamBen1 = Mole(
      name: "Skinneben",
      bodyPart: "Right Leg",
      isReminderActive: true,
      reminderFrequency: .monthly,
      nextDueDate: calendar.date(byAdding: .month, value: 1, to: today),
      person: person1
    )

    let adamBen2 = Mole(
      name: "Læg",
      bodyPart: "Right Leg",
      isReminderActive: true,
      reminderFrequency: .monthly,
      nextDueDate: calendar.date(byAdding: .month, value: 1, to: today),
      person: person1
    )
    
    let adamBen3 = Mole(
      name: "Skinneben",
      bodyPart: "Right Leg",
      isReminderActive: true,
      reminderFrequency: .monthly,
      nextDueDate: calendar.date(byAdding: .month, value: 1, to: today),
      person: person1
    )
     
    let adamArm  = Mole(
      name: "Biceps",
      bodyPart: "Right Arm",
      isReminderActive: true,
      reminderFrequency: .monthly,
      nextDueDate: calendar.date(byAdding: .month, value: 1, to: today),
      person: person1
    )

    let adamArm2  = Mole(
      name: "Triceps Øvre",
      bodyPart: "Right Arm",
      isReminderActive: true,
      reminderFrequency: .monthly,
      nextDueDate: calendar.date(byAdding: .month, value: 1, to: today),
      person: person1
    )

    let adamArm3  = Mole(
      name: "Triceps Nedre",
      bodyPart: "Right Arm",
      isReminderActive: true,
      reminderFrequency: .monthly,
      nextDueDate: calendar.date(byAdding: .month, value: 1, to: today),
      person: person1
    )

      

    // Create Scans with placeholder image data
    let adamSkulder1 = MoleScan(
      captureDate: daysAgo(100, from: today),
      imageData: UIImage(named: "15.1")?.pngData(),
      diameter: 6.98,
      area: 25.03,
      mole: adamBackMole
    )
    let adamSkulder2 = MoleScan(
      captureDate: daysAgo(90, from: today),
      imageData: UIImage(named: "15.2")?.pngData(),
      diameter: 6.66,
      area: 24.48,
      mole: adamBackMole
    )
    let adamSkulder3 = MoleScan(
      captureDate: daysAgo(80, from: today),
      imageData: UIImage(named: "15.3")?.pngData(),
      diameter: 7.66,
      area: 28.65,
      mole: adamBackMole
    )

    let adamSkulder4 = MoleScan(
      captureDate: daysAgo(70, from: today),
      imageData: UIImage(named: "14.1")?.pngData(),
      diameter: 9.51,
      area: 41.94,
      mole: adamBackMole
    )

    let adamSkulder5 = MoleScan(
      captureDate: daysAgo(0, from: today),
      imageData: UIImage(named: "14.2")?.pngData(),
      diameter: 9.64,
      area: 46.2,
      mole: adamBackMole
    )

    let adamLænd1 = MoleScan(
      captureDate: daysAgo(50, from: today),
      imageData: UIImage(named: "14.1")?.pngData(),
      diameter: 9.47,
      area: 48.15,
      mole: adamBackMole2
    )

    let adamLænd2 = MoleScan(
      captureDate: daysAgo(0, from: today),
      imageData: UIImage(named: "14.1")?.pngData(),
      diameter: 9.42,
      area: 48.94,
      mole: adamBackMole2
    )

    let adamStorLænd = MoleScan(
      captureDate: daysAgo(20, from: today),
      imageData: UIImage(named: "14.1")?.pngData(),
      diameter: 12.5,
      area: 122.72,
      mole: adamBackMole3
    )
    
    let adamHåndScan = MoleScan(
      captureDate: daysAgo(50, from: today),
      imageData: UIImage(named: "14.1")?.pngData(),
      diameter: 4.2,
      area: 13.85,
      mole: adamHånd
    )

    let adamHåndScan2 = MoleScan(
      captureDate: daysAgo(10, from: today),
      imageData: UIImage(named: "14.2")?.pngData(),
      diameter: 4.2,
      area: 13.85,
      mole: adamHånd
    )

    let adamBenScan1 = MoleScan(
      captureDate: daysAgo(15, from: today),
      imageData: UIImage(named: "14.2")?.pngData(),
      diameter: 5.2,
      area: 21.24,
      mole: adamBen1
    )
    
    let adamBenScan2 = MoleScan(
      captureDate: daysAgo(5, from: today),
      imageData: UIImage(named: "14.2")?.pngData(),
      diameter: 5.2,
      area: 23.76,
      mole: adamBen1
    )

    let adamBenScan3 = MoleScan(
      captureDate: daysAgo(0, from: today),
      imageData: UIImage(named: "14.2")?.pngData(),
      diameter: 5.5,
      area: 23.76,
      mole: adamBen2
    )

    let adamBenScan4 = MoleScan(
      captureDate: daysAgo(100, from: today),
      imageData: UIImage(named: "15.1")?.pngData(),
      diameter: 5.8,
      area: 26.42,
      mole: adamBen3
    )

    let adamBenScan5 = MoleScan(
      captureDate: daysAgo(25, from: today),
      imageData: UIImage(named: "15.2")?.pngData(),
      diameter: 6.0,
      area: 28.27,
      mole: adamBen3
    )

    let adamArmScan = MoleScan(
      captureDate: daysAgo(25, from: today),
      imageData: UIImage(named: "15.1")?.pngData(),
      diameter: 3.5,
      area: 9.62,
      mole: adamArm
    )

    let adamArmScan2 = MoleScan(
      captureDate: daysAgo(2, from: today),
      imageData: UIImage(named: "15.2")?.pngData(),
      diameter: 3.5,
      area: 9.62,
      mole: adamArm
    )

    let adamArmScan3 = MoleScan(
      captureDate: daysAgo(120, from: today),
      imageData: UIImage(named: "15.3")?.pngData(),
      diameter: 4.0,
      area: 12.57,
      mole: adamArm2
    )

    let adamArmScan4 = MoleScan(
      captureDate: daysAgo(200, from: today),
      imageData: UIImage(named: "14.2")?.pngData(),
      diameter: 4.2,
      area: 13.85,
      mole: adamArm3
    )

     let adamArmScan5 = MoleScan(
       captureDate: daysAgo(100, from: today),
       imageData: UIImage(named: "14.3")?.pngData(),
       diameter: 4.2,
       area: 13.85,
       mole: adamArm3
     )

    
    // Insert Objects
    context.insert(person1)
    context.insert(adamBackMole)
    context.insert(adamBackMole2)
    context.insert(adamBackMole3)
    context.insert(adamHånd)
    context.insert(adamBen1)
    context.insert(adamBen2)
    context.insert(adamBen3)
    context.insert(adamArm)
    context.insert(adamArm2)
    context.insert(adamArm3)
    context.insert(adamSkulder1)
    context.insert(adamSkulder2)
    context.insert(adamSkulder3)
    context.insert(adamSkulder4)
    context.insert(adamSkulder5)
    context.insert(adamLænd1)
    context.insert(adamLænd2)
    context.insert(adamStorLænd)
    context.insert(adamHåndScan)
    context.insert(adamHåndScan2)
    context.insert(adamBenScan1)
    context.insert(adamBenScan2)
    context.insert(adamBenScan3)
    context.insert(adamBenScan4)
    context.insert(adamBenScan5)
    context.insert(adamArmScan)
    context.insert(adamArmScan2)
    context.insert(adamArmScan3)
    context.insert(adamArmScan4)
    context.insert(adamArmScan5)
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
