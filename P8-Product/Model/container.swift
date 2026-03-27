//
// Container.swift
// P8-Product
//

import Foundation
import SwiftData

/// `DataController` handles the initialization of the `ModelContainer`, environment-specific
/// configurations (e.g., in-memory storage for testing), and safe recovery from database
/// initialization failures.
@MainActor
class DataController {
    
    static let shared = DataController()
    
    /// The managed container that holds the schema and storage configuration.
    let container: ModelContainer

    /// Initializes the data stack, attempting to load the persistent store or resetting it if loading fails.
    init() {
        do {
            container = try Self.makePersistentContainer()
            checkAndSeed()
        } catch {
            // Fallback: If the schema changed, the container fails to build.
            // We CANNOT call container.erase() here because we don't have a container.
            // We must delete the SQLite files manually to recover safely.
            do {
                try Self.deleteStoreFiles()
                container = try Self.makePersistentContainer()
                checkAndSeed()
            } catch {
                fatalError("Could not initialize SwiftData after resetting the local store: \(error)")
            }
        }
    }

    // Wipes all data from the persistent container
    func eraseAllData() throws {
        // Try iOS 18+ native erase first
        if #available(iOS 18, *) {
            try container.erase()
        } else {
            // Fallback for earlier iOS versions: manually delete store files
            try Self.deleteStoreFiles()
        }
    }
    
    // Checks if the database is empty and populates it with sample data if necessary.
    // This is typically called only once during the first launch or after a store reset.
    private func checkAndSeed() {
        let context = container.mainContext
        let descriptor = FetchDescriptor<Person>()

        // Only insert if the database is empty
        if let existing = try? context.fetch(descriptor), existing.isEmpty {
            MockData.insertSampleData(into: context)
            try? context.save()
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
        // or during a unit/UI test run.
        let isTesting = ProcessInfo.processInfo.environment["CI"] == "true" ||
                        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

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
        let appSupport = URL.applicationSupportDirectory
        let directory = appSupport.appending(path: "P8-Product", directoryHint: .isDirectory)

        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "default.store")
    }

    /// Manually removes the SQLite database files from the file system.
    ///
    /// This is used as a "nuclear option" when the `ModelContainer` cannot initialize
    /// due to schema mismatches or file corruption. It targets the main store,
    /// the Shared Memory (-shm) file, and the Write-Ahead Log (-wal) file.
    private static func deleteStoreFiles() throws {
        let storeURL = storeURL
        let storePath = storeURL.path()
        
        let relatedURLs = [
            storeURL,
            URL(fileURLWithPath: storePath + "-shm"),
            URL(fileURLWithPath: storePath + "-wal")
        ]

        for url in relatedURLs where FileManager.default.fileExists(atPath: url.path()) {
            try FileManager.default.removeItem(at: url)
        }
    }
}
