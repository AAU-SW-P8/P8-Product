import Foundation
import SwiftData

@MainActor
class DataController {
    static let shared = DataController()
    let container: ModelContainer

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

    // Wipes all data from the container (iOS 18)
    func eraseAllData() throws {
            try container.erase()
    }
    
    private func checkAndSeed() {
        let context = container.mainContext
        let descriptor = FetchDescriptor<Person>()

        // Only insert if the database is empty
        if let existing = try? context.fetch(descriptor), existing.isEmpty {
            MockData.insertSampleData(into: context)
            // No need to call save manually usually, but good for immediate persistence
            try? context.save()
        }
    }

    private static func makePersistentContainer() throws -> ModelContainer {
        let schema = Schema([
            Person.self,
            Mole.self,
            MoleInstance.self,
            MoleScan.self
        ])

        let config = ModelConfiguration(url: storeURL)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private static var storeURL: URL {
        let appSupport = URL.applicationSupportDirectory
        let directory = appSupport.appending(path: "P8-Product", directoryHint: .isDirectory)

        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "default.store")
    }

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
