import Foundation
import Testing
@testable import ExerciseSnacks

struct PersistenceTests {
    @Test func preferencesSurviveStorageAndExportImport() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let original = StoredData(libraryText: "pushups\nplank\ndead hang", snacks: [], exercisePreferences: [
            "pushups": ExercisePreferences(isMuted: true),
            "plank": ExercisePreferences(isMuted: true, isBoosted: true),
            "dead hang": ExercisePreferences(isBoosted: true)
        ])
        let disk = LocalDataStore(fileURL: url)
        try await disk.save(original)
        #expect(try await disk.load() == original)
        let exported = try JSONCodec.encoder().encode(ExportPayload(data: original))
        #expect(try JSONCodec.importData(exported) == original)
    }

    @Test func rejectsPreferencesForMissingExercisesAndMalformedFlags() throws {
        let json = #"{"version":1,"library":["plank"],"snacks":[],"exercisePreferences":{"pushups":{"isMuted":true,"isBoosted":false}}}"#
        #expect(throws: (any Error).self) { try JSONCodec.importData(Data(json.utf8)) }
        let malformed = #"{"version":1,"library":["plank"],"snacks":[],"exercisePreferences":{"plank":{"isMuted":"yes","isBoosted":false}}}"#
        #expect(throws: (any Error).self) { try JSONCodec.importData(Data(malformed.utf8)) }
    }

    private func temporaryURL() -> URL {
        URL.temporaryDirectory.appending(path: UUID().uuidString).appending(path: "data.json")
    }

    @Test func firstLaunchSeedsButAnEmptyLibraryStaysEmpty() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let disk = LocalDataStore(fileURL: url)
        #expect(try await disk.load() == .seed)
        let empty = StoredData(libraryText: "", snacks: [])
        try await disk.save(empty)
        #expect(try await LocalDataStore(fileURL: url).load() == empty)
    }

    @Test func corruptFileIsPreserved() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let bytes = Data("not valid JSON".utf8)
        try bytes.write(to: url)
        await #expect(throws: (any Error).self) { try await LocalDataStore(fileURL: url).load() }
        #expect(try Data(contentsOf: url) == bytes)
    }

    @Test func exportImportPreservesHistoryAndNormalizesLibrary() throws {
        let snack = Snack(id: UUID(), completedAt: Date(timeIntervalSince1970: 1_800_000_000.125), exercises: ["old exercise"])
        let original = StoredData(libraryText: " pushups \n\npushups\nDead Hang\n", snacks: [snack])
        let bytes = try JSONCodec.encoder().encode(ExportPayload(data: original))
        let imported = try JSONCodec.importData(bytes)
        #expect(imported.libraryText == "pushups\nDead Hang")
        #expect(imported.snacks == [snack])
        #expect(imported.activeSession == nil)
        #expect(!String(decoding: bytes, as: UTF8.self).contains("activeSession"))
    }

    @Test func acceptsPRDSampleTimestamp() throws {
        let bytes = Data("""
        {"version":1,"library":[],"snacks":[{"id":"C3E1D340-D34A-4A09-9FAD-CA0DE1ED3E60","completedAt":"2026-09-22T18:45:00Z","exercises":["pushups"]}]}
        """.utf8)
        #expect(try JSONCodec.importData(bytes).snacks.count == 1)
    }

    @Test(arguments: [
        "{}",
        "{\"version\":2,\"library\":[],\"snacks\":[]}",
        "{\"version\":1,\"library\":[\"a\\nb\"],\"snacks\":[]}",
        "{\"version\":1,\"library\":[\" \"],\"snacks\":[]}"
    ])
    func rejectsMalformedImports(json: String) {
        #expect(throws: (any Error).self) { try JSONCodec.importData(Data(json.utf8)) }
    }

    @Test func rejectsDuplicateIDsInvalidCountsAndNames() throws {
        let one = Snack(id: UUID(), completedAt: Date(), exercises: ["a"])
        #expect(throws: (any Error).self) { try DataValidation.snacks([one, one]) }
        #expect(throws: (any Error).self) {
            try DataValidation.snacks([Snack(id: UUID(), completedAt: Date(), exercises: ["a", "b"])])
        }
        #expect(throws: (any Error).self) {
            try DataValidation.snacks([Snack(id: UUID(), completedAt: Date(), exercises: ["a", "A", "b"])])
        }
    }

    @Test func tenThousandEntriesRoundTrip() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let records = (0..<10_000).map {
            Snack(id: UUID(), completedAt: Date(timeIntervalSince1970: 1_800_000_000 - Double($0 * 300)), exercises: ["pushups", "dead hang", "plank"])
        }
        let data = StoredData(libraryText: SeedLibrary.text, snacks: records)
        let disk = LocalDataStore(fileURL: url)
        try await disk.save(data)
        let restored = try await disk.load()
        #expect(restored.snacks == records)
        #expect(HistoryGrouping.sections(for: restored.snacks).flatMap(\.snacks).count == 10_000)
    }
}
