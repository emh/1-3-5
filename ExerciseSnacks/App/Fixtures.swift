import Foundation

extension AppTheme {
    @MainActor static let preferences: UserDefaults = {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            let name = "ExerciseSnacks-UITests"
            let defaults = UserDefaults(suiteName: name)!
            if ProcessInfo.processInfo.arguments.contains("--reset-test-data") {
                defaults.removePersistentDomain(forName: name)
            }
            return defaults
        }
        #endif
        return .standard
    }()
}

#if DEBUG
actor MemoryDataStore: DataPersistence {
    private var data: StoredData
    init(_ data: StoredData) { self.data = data }
    func load() -> StoredData { data }
    func save(_ data: StoredData) { self.data = data }
}

enum Fixtures {
    static var history: StoredData {
        let now = Date()
        let minutes: [(Int, [String])] = [
            (4, ["pushups", "dead hang", "hip airplanes"]),
            (125, ["kettlebell swings"]),
            (245, ["lunges", "pushups", "cossack squats", "hollow hold", "dead hang"]),
            (24 * 60, ["air squats", "side plank", "bird dog"]),
            (26 * 60, ["dead hang"]),
            (29 * 60, ["kettlebell swings", "lunges", "deep squat", "pushups", "calf raises"])
        ]
        return StoredData(libraryText: SeedLibrary.text, snacks: minutes.map {
            Snack(id: UUID(), completedAt: now.addingTimeInterval(Double(-$0.0 * 60)), exercises: $0.1)
        })
    }
}

extension AppStore {
    static func preview(data: StoredData = Fixtures.history) -> AppStore {
        AppStore(persistence: MemoryDataStore(data))
    }
}
#endif

extension AppStore {
    static func launchStore() -> AppStore {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--fixture-history") { return preview() }
        if args.contains("--ui-testing") {
            let url = URL.applicationSupportDirectory.appending(path: "ExerciseSnacks-UITests/data.json")
            if args.contains("--reset-test-data") { try? FileManager.default.removeItem(at: url) }
            let seed = args.contains("--empty-library") ? StoredData(libraryText: "", snacks: []) : .seed
            return AppStore(persistence: LocalDataStore(fileURL: url, seed: seed))
        }
        #endif
        return AppStore()
    }
}
