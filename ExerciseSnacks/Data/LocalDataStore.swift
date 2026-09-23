import Foundation

protocol DataPersistence: Sendable {
    func load() async throws -> StoredData
    func save(_ data: StoredData) async throws
}

actor LocalDataStore: DataPersistence {
    let fileURL: URL
    private let seed: StoredData

    init(fileURL: URL = LocalDataStore.defaultURL, seed: StoredData = .seed) {
        self.fileURL = fileURL
        self.seed = seed
    }

    static var defaultURL: URL {
        URL.applicationSupportDirectory
            .appending(path: "ExerciseSnacks", directoryHint: .isDirectory)
            .appending(path: "data.json")
    }

    func load() throws -> StoredData {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            try save(seed)
            return seed
        }
        var data = try JSONCodec.decoder().decode(StoredData.self, from: Data(contentsOf: fileURL))
        try DataValidation.stored(data)
        data.snacks.sort { $0.completedAt > $1.completedAt }
        return data
    }

    func save(_ data: StoredData) throws {
        try DataValidation.stored(data)
        let bytes = try JSONCodec.encoder().encode(data)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try bytes.write(to: fileURL, options: .atomic)
    }

    static func readImport(at url: URL) throws -> StoredData {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        return try JSONCodec.importData(Data(contentsOf: url))
    }

    static func exportFile(for data: StoredData) throws -> URL {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let date = Date().formatted(.iso8601.year().month().day().dateSeparator(.dash))
        let url = directory.appending(path: "exercise-snacks-\(date).json")
        try JSONCodec.encoder().encode(ExportPayload(data: data)).write(to: url, options: .atomic)
        return url
    }
}
