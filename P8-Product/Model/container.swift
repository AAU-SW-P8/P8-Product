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

        // Detect if the app is running in a Continuous Integration (CI) environment
        // or during a unit/UI test run. UI tests launch the app as a separate
        // process that does not inherit `XCTestConfigurationFilePath`, so we also
        // honor an explicit launch argument to force an in-memory store.
        let isTesting = ProcessInfo.processInfo.environment["CI"] == "true" ||
                        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
                        ProcessInfo.processInfo.arguments.contains("-UITest_EmptyStore")

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

    /// Manually removes the SQLite database files from the file system.
    ///
    /// This is used as a "nuclear option" when the `ModelContainer` cannot initialize
    /// due to schema mismatches or file corruption. It targets the main store,
    /// the Shared Memory (-shm) file, and the Write-Ahead Log (-wal) file.
    private static func deleteStoreFiles() throws {
        let storeURL: URL = storeURL
        let storePath: String = storeURL.path()
        
        let relatedURLs: [URL] = [
            storeURL,
            URL(fileURLWithPath: storePath + "-shm"),
            URL(fileURLWithPath: storePath + "-wal")
        ]

        for url: URL in relatedURLs where FileManager.default.fileExists(atPath: url.path()) {
            try FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - Business Logic & Persistence
    
    /// Creates a new scan, a new mole, and links them together for a specific person.
    func addMoleAndScan(to person: Person, image: UIImage) {
        let context: ModelContext = container.mainContext
        
        let scan = MoleScan(imageData: image.jpegData(compressionQuality: 0.9))
        let mole: Mole = Mole(
            name: "Mole \(person.moles.count + 1)",
            bodyPart: "Unassigned",
            isReminderActive: false,
            reminderFrequency: nil,
            nextDueDate: nil,
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
    
    func delete(_ person: Person) {
        let context: ModelContext = container.mainContext
        context.delete(person)
        do {
            try context.save()
        } catch {
            print("Failed to delete person: \(error)")
        }
    }
    
    func delete(_ mole: Mole) {
        let context: ModelContext = container.mainContext
        context.delete(mole)
        do {
            try context.save()
        } catch {
            print("Failed to delete mole: \(error)")
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

}
