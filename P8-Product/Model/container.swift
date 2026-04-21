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
    
    static let shared: DataController = DataController()
    
    /// The managed container that holds the schema and storage configuration.
    let container: ModelContainer

    /// Initializes the data stack, attempting to load the persistent store or resetting it if loading fails.
    init() {
        let shouldSeedInitialData = !ProcessInfo.processInfo.arguments.contains("-disableMockData")
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

    // Wipes all data from the persistent container (iOS 18)
    func eraseAllData() {
        do {
            try container.erase()
        } catch {
            print("Failed to erase all data: \(error)")
        }
    }
    
    // Checks if the database is empty and populates it with sample data if necessary.
    // This is typically called only once during the first launch or after a store reset.
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
            MoleInstance.self,
            MoleScan.self
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
        let isTesting = ProcessInfo.processInfo.environment["CI"] == "true" ||
                ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
                arguments.contains("-UITest_EmptyStore") ||
                arguments.contains("-UITest_InMemoryStore")

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
            URL(fileURLWithPath: storePath + "-wal")
        ]

        for url in relatedURLs where FileManager.default.fileExists(atPath: url.path()) {
            try FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - Business Logic & Persistence
    
    /// Creates a new scan, a new mole, and links them together for a specific person.
    func addMoleAndScan(
        to person: Person,
        image: UIImage,
        name: String? = nil,
        bodyPart: String = BodyPart.unassigned.rawValue
    ) {
        let context: ModelContext = container.mainContext
        let trimmedName: String = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let resolvedName: String = trimmedName.isEmpty ? "Mole \(person.moles.count + 1)" : trimmedName
        
        let scan: MoleScan = MoleScan(imageData: image.jpegData(compressionQuality: 0.9))
        let initialDueDate: Date? = nextDueDate(
            for: person.defaultReminderFrequency,
            referenceDate: scan.captureDate,
            isEnabled: person.defaultReminderEnabled
        )
        let mole: Mole = Mole(
            name: resolvedName,
            bodyPart: bodyPart,
            isReminderActive: person.defaultReminderEnabled,
            reminderFrequency: nil,
            nextDueDate: initialDueDate,
            person: person
        )
        let instance: MoleInstance = MoleInstance(
            diameter: 0,
            area: 0,
            mole: mole, 
            moleScan: scan
        )
        
        context.insert(scan)
        context.insert(mole)
        context.insert(instance)
        
        do {
            try context.save()
        } catch {
            print("Failed to save new mole and scan: \(error)")
        }
    }
    
    /**
        Adds a new scan to an existing mole by creating a new `MoleScan` and linking it with a new `MoleInstance`.
        - Parameters:
            - mole: The existing `Mole` to which the new scan will be linked.
            - image: The `UIImage` representing the new scan to be added.
    */
    func addToExistingMole(mole: Mole, image: UIImage) {
        let context: ModelContext = container.mainContext
        
        // Create the scan and the linking instance
        let scan: MoleScan = MoleScan(imageData: image.jpegData(compressionQuality: 0.9))
        let instance: MoleInstance = MoleInstance(
            diameter: 0,
            area: 0,
            mole: mole,
            moleScan: scan
        )

        context.insert(scan)
        context.insert(instance)
        recalculateNextDueDate(for: mole)

        do {
            try context.save()
        } catch {
            print("Failed to save scan to existing mole: \(error)")
        }
    }

    func effectiveReminderEnabled(for mole: Mole) -> Bool {
        if mole.followDefaultReminderEnabled ?? true {
            return mole.person?.defaultReminderEnabled ?? mole.isReminderActive
        }
        return mole.isReminderActive
    }

    func effectiveFrequencyLabel(for mole: Mole) -> String? {
        if mole.followDefault ?? true {
            return mole.person?.defaultReminderFrequency
        }
        return mole.reminderFrequency?.rawValue
    }

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

    func latestCaptureDate(for mole: Mole, excluding excludedInstance: MoleInstance? = nil) -> Date? {
        mole.instances
            .filter { instance in
                guard let excludedInstance else { return true }
                return instance !== excludedInstance
            }
            .compactMap { $0.moleScan?.captureDate }
            .max()
    }

    func recalculateNextDueDate(for mole: Mole, excluding excludedInstance: MoleInstance? = nil) {
        guard effectiveReminderEnabled(for: mole),
              let frequencyLabel = effectiveFrequencyLabel(for: mole),
              let captureDate = latestCaptureDate(for: mole, excluding: excludedInstance) else {
            mole.nextDueDate = nil
            return
        }

        mole.nextDueDate = nextDueDate(
            for: frequencyLabel,
            referenceDate: captureDate,
            isEnabled: true
        )
    }

    func delete(_ person: Person) {
        deleteAndSave(errorMessage: "Failed to delete person") { context in
            context.delete(person)
        }
    }
    
    func delete(_ mole: Mole) {
        deleteAndSave(errorMessage: "Failed to delete mole") { context in
            context.delete(mole)
        }
    }

    func delete(_ instance: MoleInstance) {
        deleteAndSave(errorMessage: "Failed to delete mole instance") { context in
            let associatedScan = instance.moleScan
            let hasOtherInstances: Bool = associatedScan?.instances.contains { $0 !== instance} ?? false
            
            if let associatedScan, !hasOtherInstances {
                context.delete(associatedScan)
            }
            else {
                context.delete(instance)
            }
        }
    }

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
    
    func addPerson(name: String) -> Person {
        let context: ModelContext = container.mainContext
        let person: Person = Person(name: name)
        context.insert(person)
        do {
            try context.save()
        } catch {
            print("Failed to add person: \(error)")
        }
        return person
    }

    func rename(_ person: Person, to newName: String) {
        let context: ModelContext = container.mainContext
        person.name = newName
        do {
            try context.save()
        } catch {
            print("Failed to rename person: \(error)")
        }
    }

}
