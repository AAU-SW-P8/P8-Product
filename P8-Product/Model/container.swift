//
// Container.swift
// P8-Product
//

import Foundation
import SwiftData
import UIKit

/// `DataController` handles the initialization of the `ModelContainer`, environment-specific
/// configurations (e.g., in-memory storage for testing), and safe recovery from database
/// initialization failures.
@MainActor
class DataController {

  /// The singleton shared instance of `DataController`.
  static let shared: DataController = DataController()

  /// The managed container that holds the schema and storage configuration.
  let container: ModelContainer

  /// Initializes the data stack, attempting to load the persistent store or resetting it if loading fails.
  init() {
    let shouldSeedInitialData =
      !ProcessInfo.processInfo.arguments.contains("-disableMockData")
      && ProcessInfo.processInfo.environment["DISABLE_MOCK_DATA"] != "1"

    do {
      container = try Self.makePersistentContainer()
      if shouldSeedInitialData {
        checkAndSeed()
      }
    } catch {
      // Fallback: If the schema changed, the container fails to build.
      // We CANNOT call container.erase() here because we don't have a container.
      // We must delete the SQLite files manually to recover safely.
      do {
        try Self.deleteStoreFiles()
        container = try Self.makePersistentContainer()
        if shouldSeedInitialData {
          checkAndSeed()
        }
      } catch {
        fatalError("Could not initialize SwiftData after resetting the local store: \(error)")
      }
    }
  }

  /// Wipes all data from the persistent container (iOS 18).
  func eraseAllData() {
    do {
      try container.erase()
    } catch {
      print("Failed to erase all data: \(error)")
    }
  }

  /// Checks if the database is empty and populates it with sample data if necessary.
  /// Typically called only once during the first launch or after a store reset.
  private func checkAndSeed() {
    // Allow UI tests to start with an empty store
    if ProcessInfo.processInfo.arguments.contains("-UITest_EmptyStore") {
      return
    }

    let context: ModelContext = container.mainContext
    let descriptor: FetchDescriptor<Person> = FetchDescriptor<Person>()

    // Only insert if the database is empty
    if let existing: [Person] = try? context.fetch(descriptor), existing.isEmpty {
      MockData.insertSampleData(into: context)
      do {
        try context.save()
      } catch {
        print("Failed to seed initial data: \(error)")
      }
    }
  }

  /// Configures and returns a `ModelContainer` based on the current execution environment.
  /// - Returns: A configured `ModelContainer`
  private static func makePersistentContainer() throws -> ModelContainer {
    let schema = Schema([
      Person.self,
      Mole.self,
      MoleScan.self,
    ])

    let arguments = ProcessInfo.processInfo.arguments

    // Optional UI-test mode that persists across relaunches, isolated from production data.
    if arguments.contains("-UITest_PersistentStore") {
      if arguments.contains("-UITest_ResetStore") {
        try? deleteStoreFiles(at: uiTestPersistentStoreURL)
      }

      let config = ModelConfiguration(schema: schema, url: uiTestPersistentStoreURL)
      return try ModelContainer(for: schema, configurations: [config])
    }

    // Detect if the app is running in a Continuous Integration (CI) environment
    // or during a unit/UI test run. UI tests launch the app as a separate
    // process that does not inherit `XCTestConfigurationFilePath`, so we also
    // honor an explicit launch argument to force an in-memory store.
    let isTesting =
      ProcessInfo.processInfo.environment["CI"] == "true"
      || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
      || arguments.contains("-UITest_EmptyStore") || arguments.contains("-UITest_InMemoryStore")

    let config: ModelConfiguration
    if isTesting {
      // In-memory for testing isolation
      config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    } else {
      // Persistent storage for production
      config = ModelConfiguration(schema: schema, url: storeURL)
    }
    return try ModelContainer(for: schema, configurations: [config])
  }

  /// The file system URL where the persistent SQLite store is located.
  private static var storeURL: URL {
    let appSupport: URL = URL.applicationSupportDirectory
    let directory: URL = appSupport.appending(path: "P8-Product", directoryHint: .isDirectory)
    do {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    } catch {
      fatalError("Failed to create application support directory: \(error)")
    }
    return directory.appending(path: "default.store")
  }

  /// Dedicated on-disk store for UI tests that need persistence across relaunches.
  private static var uiTestPersistentStoreURL: URL {
    let tempDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("P8-Product-UITestStore", isDirectory: true)
    do {
      try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    } catch {
      fatalError("Failed to create UI test store directory: \(error)")
    }
    return tempDir.appendingPathComponent("default.store", isDirectory: false)
  }

  /// Manually removes the SQLite database files from the file system.
  ///
  /// This is used as a "nuclear option" when the `ModelContainer` cannot initialize
  /// due to schema mismatches or file corruption. It targets the main store,
  /// the Shared Memory (-shm) file, and the Write-Ahead Log (-wal) file.
  private static func deleteStoreFiles() throws {
    try deleteStoreFiles(at: storeURL)
  }

  /// Removes a SQLite store and sidecar files for the given URL.
  private static func deleteStoreFiles(at storeURL: URL) throws {
    let storePath = storeURL.path()

    let relatedURLs: [URL] = [
      storeURL,
      URL(fileURLWithPath: storePath + "-shm"),
      URL(fileURLWithPath: storePath + "-wal"),
    ]

    for url in relatedURLs where FileManager.default.fileExists(atPath: url.path()) {
      try FileManager.default.removeItem(at: url)
    }
  }

  // MARK: - Business Logic & Persistence

  /// Creates a new scan, a new mole, and links them together for a specific person.
  /// Returns `false` when a duplicate mole name is detected for that person.
  @discardableResult
  func addMoleAndScan(
    to person: Person,
    image: UIImage,
    name: String? = nil,
    bodyPart: String = BodyPart.unassigned.rawValue,
    area: Float = 0,
    diameter: Float = 0
  ) -> Bool {
    let context: ModelContext = container.mainContext
    let trimmedName: String = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let resolvedName: String =
      trimmedName.isEmpty
      ? nextAvailableAutoMoleName(for: person)
      : trimmedName

    guard !hasMole(named: resolvedName, for: person) else {
      return false
    }
    let mole: Mole = Mole(
      name: resolvedName,
      bodyPart: bodyPart,
      isReminderActive: person.defaultReminderEnabled,
      reminderFrequency: nil,
      nextDueDate: nil,
      person: person
    )

    let scan: MoleScan = MoleScan(
      imageData: image.jpegData(compressionQuality: 0.9), diameter: diameter, area: area, mole: mole
    )
    mole.nextDueDate = nextDueDate(
      for: person.defaultReminderFrequency,
      referenceDate: scan.captureDate,
      isEnabled: person.defaultReminderEnabled
    )

    context.insert(mole)
    context.insert(scan)

    do {
      try context.save()
      return true
    } catch {
      print("Failed to save new mole and scan: \(error)")
      return false
    }
  }

  /// Returns `true` when the given person already has a mole with a normalised name equal to `candidateName`.
  /// - Parameters:
  ///   - candidateName: The name to check for duplicates.
  ///   - person: The person whose mole list is searched.
  ///   - excludedMole: An optional mole to skip during the check (useful when renaming).
  func hasMole(named candidateName: String, for person: Person, excluding excludedMole: Mole? = nil)
    -> Bool
  {
    let normalizedCandidate: String = normalizedMoleName(candidateName)
    guard !normalizedCandidate.isEmpty else { return false }

    return person.moles.contains { mole in
      guard excludedMole == nil || mole !== excludedMole else { return false }
      return normalizedMoleName(mole.name) == normalizedCandidate
    }
  }

  /// Returns the next unused auto-generated mole name (e.g., "Mole 3") for the given person.
  private func nextAvailableAutoMoleName(for person: Person) -> String {
    var index: Int = max(1, person.moles.count + 1)
    var candidate = "Mole \(index)"

    while hasMole(named: candidate, for: person) {
      index += 1
      candidate = "Mole \(index)"
    }

    return candidate
  }

  /// Returns a trimmed, case- and diacritic-insensitive version of the mole name for deduplication.
  private func normalizedMoleName(_ name: String) -> String {
    name
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
  }

  /// Adds a new scan to an existing mole by creating a new `MoleScan`.
  /// - Parameters:
  ///   - mole: The existing `Mole` to which the new scan will be linked.
  ///   - image: The `UIImage` representing the new scan to be added.
  func addToExistingMole(mole: Mole, image: UIImage, area: Float = 0, diameter: Float = 0) {
    let context: ModelContext = container.mainContext

    // Create the scan and the linking instance
    let scan: MoleScan = MoleScan(
      imageData: image.jpegData(compressionQuality: 0.9),
      diameter: diameter,
      area: area,
      mole: mole)

    context.insert(scan)
    recalculateNextDueDate(for: mole)

    do {
      try context.save()
    } catch {
      print("Failed to save scan to existing mole: \(error)")
    }
  }

  /// Returns whether reminders are effectively enabled for a mole, respecting any per-mole overrides.
  func effectiveReminderEnabled(for mole: Mole) -> Bool {
    if mole.followDefaultReminderEnabled ?? true {
      return mole.person?.defaultReminderEnabled ?? mole.isReminderActive
    }
    return mole.isReminderActive
  }

  /// Returns the effective reminder frequency label for a mole, falling back to the person's default.
  func effectiveFrequencyLabel(for mole: Mole) -> String? {
    if mole.followDefault ?? true {
      return mole.person?.defaultReminderFrequency
    }
    return mole.reminderFrequency?.rawValue
  }

  /// Calculates the next due date based on a frequency label and a reference date.
  /// - Parameters:
  ///   - frequencyLabel: A string such as "Weekly", "Monthly", or "Quarterly".
  ///   - referenceDate: The date from which the interval is calculated.
  ///   - isEnabled: When `false`, returns `nil` immediately.
  /// - Returns: The computed next due date, or `nil` if reminders are disabled or frequency is unknown.
  func nextDueDate(for frequencyLabel: String?, referenceDate: Date, isEnabled: Bool) -> Date? {
    guard isEnabled, let frequencyLabel else { return nil }

    let calendar: Calendar = Calendar.current
    let computedDate: Date?
    switch frequencyLabel.lowercased() {
    case "weekly":
      computedDate = calendar.date(byAdding: .weekOfYear, value: 1, to: referenceDate)
    case "monthly":
      computedDate = calendar.date(byAdding: .month, value: 1, to: referenceDate)
    case "quarterly":
      computedDate = calendar.date(byAdding: .month, value: 3, to: referenceDate)
    default:
      computedDate = nil
    }

    guard let computedDate else { return nil }
    return max(Date(), computedDate)
  }

  /// Returns the most recent capture date for the given mole.
  ///
  /// If an `excludedScan` is provided, that scan is ignored when determining the latest date.
  /// - Parameters:
  ///   - mole: The mole whose scans should be evaluated.
  ///   - excludedScan: An optional scan to exclude from the search.
  /// - Returns: The latest capture date among the mole’s remaining scans, or `nil` if no valid date exists.
  func latestCaptureDate(for mole: Mole, excluding excludedScan: MoleScan? = nil) -> Date? {
    mole.scans
      .filter { scan in
        guard let excludedScan else { return true }
        return scan !== excludedScan
      }
      .map(\.captureDate)
      .max()
  }

  /// Recalculates the next due date for a mole based on its scan history.
  ///
  /// This function updates the `nextDueDate` property of the specified mole by analyzing its scan records
  /// and determining when the next examination should be scheduled. An optional scan can be excluded from
  /// the calculation, which is useful when removing or updating a specific scan.
  ///
  /// - Parameters:
  ///   - mole: The `Mole` object for which to recalculate the next due date.
  ///   - excludedScan: An optional `MoleScan` to exclude from the calculation. If provided, this scan
  ///     will be ignored when determining the next due date. Defaults to `nil`.
  func recalculateNextDueDate(for mole: Mole, excluding excludedScan: MoleScan? = nil) {
    guard effectiveReminderEnabled(for: mole),
      let frequencyLabel = effectiveFrequencyLabel(for: mole),
      let captureDate = latestCaptureDate(for: mole, excluding: excludedScan)
    else {
      mole.nextDueDate = nil
      return
    }

    mole.nextDueDate = nextDueDate(
      for: frequencyLabel,
      referenceDate: captureDate,
      isEnabled: true
    )
  }

  /// Deletes the specified `Person` from the container.
  ///
  /// Removes the provided `Person` instance from the underlying collection/data store.
  ///
  /// - Parameter person: The `Person` to delete.
  /// - Note: If the person does not exist in the container, this operation should have no effect.
  func delete(_ person: Person) {
    deleteAndSave(errorMessage: "Failed to delete person") { context in
      context.delete(person)
    }
  }

  /// Removes a `Mole` from the container.
  ///
  /// - Parameter mole: The `Mole` instance to delete.
  func delete(_ mole: Mole) {
    deleteAndSave(errorMessage: "Failed to delete mole") { context in
      context.delete(mole)
    }
  }

  /// Deletes the specified `MoleScan` from the container.
  ///
  /// - Parameter scan: The `MoleScan` instance to remove.
  func delete(_ scan: MoleScan) {
    deleteAndSave(errorMessage: "Failed to delete scan") { context in
      context.delete(scan)
    }
  }

  /// Deletes the relevant object(s) from the persistence context and immediately saves the change.
  ///
  /// Use this helper to keep deletion logic centralized and to ensure the context is persisted
  /// right after items are marked for removal.
  ///
  /// - Important: Call this method on the correct queue/thread for the underlying persistence context.
  private func deleteAndSave(
    errorMessage: String,
    performDelete: (ModelContext) -> Void
  ) {
    let context: ModelContext = container.mainContext
    performDelete(context)
    do {
      try context.save()
    } catch {
      print("\(errorMessage): \(error)")
    }
  }

  /// Adds a new `Person` to the container using the provided name.
  ///
  /// - Parameter name: The name to assign to the newly created person.
  /// - Returns: The newly created `Person` instance.
  func addPerson(name: String) -> Person {
    let context: ModelContext = container.mainContext
    let person: Person = Person(name: name.trimmingCharacters(in: .whitespacesAndNewlines))
    context.insert(person)
    do {
      try context.save()
    } catch {
      print("Failed to add person: \(error)")
    }
    return person
  }

  /// Renames the specified person to a new name.
  ///
  /// - Parameters:
  ///   - person: The `Person` instance to rename.
  ///   - newName: The new name to assign to the person.
  func rename(_ person: Person, to newName: String) {
    let context: ModelContext = container.mainContext
    person.name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
    do {
      try context.save()
    } catch {
      print("Failed to rename person: \(error)")
    }
  }
}
