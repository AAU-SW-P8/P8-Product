//
//  P8_Product_TestApp.swift
//  P8-Product
//

@main
struct P8_Product: App {
    var container: ModelContainer = {
        let isTesting =
            ProcessInfo.processInfo.environment["CI"] == "true" || // Detect if running in a CI pipeline
            ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil // Detect if running in a test environment

        do {
            if isTesting { // Use an in-memory store for testing to ensure isolation and speed
                let config = ModelConfiguration(isStoredInMemoryOnly: true)
                return try ModelContainer(
                    for: HistoryItem.self, Person.self,
                    configurations: config
                )
            } else { // Use a persistent store for regular app runs
                return try ModelContainer(
                    for: HistoryItem.self, Person.self
                )
            }
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container) // Use the custom ModelContainer for the app
    }
}
