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
      name: "Lænd",
      bodyPart: "Back",
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
      captureDate: daysAgo(60, from: today),
      imageData: UIImage(named: "14.2")?.pngData(),
      diameter: 9.64,
      area: 46.2,
      mole: adamBackMole
    )

    let adamLænd1 = MoleScan(
      captureDate: daysAgo(50, from: today),
      imageData: UIImage(named: "lænd1")?.pngData(),
      diameter: 9.47,
      area: 48.15,
      mole: adamBackMole2
    )

    let adamLænd2 = MoleScan(
      captureDate: daysAgo(40, from: today),
      imageData: UIImage(named: "lænd2")?.pngData(),
      diameter: 9.42,
      area: 48.94,
      mole: adamBackMole2
    )
    
    // Insert Objects
    context.insert(person1)
    context.insert(adamBackMole)
    context.insert(adamBackMole2)
    context.insert(adamSkulder1)
    context.insert(adamSkulder2)
    context.insert(adamSkulder3)
    context.insert(adamSkulder4)
    context.insert(adamSkulder5)
    context.insert(adamLænd1)
    context.insert(adamLænd2)
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
