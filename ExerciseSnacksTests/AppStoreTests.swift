import Foundation
import Testing
@testable import ExerciseSnacks

private actor ControlledStorage: DataPersistence {
    private var data: StoredData
    private var failureCount = 0
    init(_ data: StoredData = .seed) { self.data = data }
    func failNextSave() { failureCount = 1 }
    func load() -> StoredData { data }
    func save(_ next: StoredData) async throws {
        try await Task.sleep(for: .milliseconds(5))
        if failureCount > 0 {
            failureCount -= 1
            throw CocoaError(.fileWriteOutOfSpace)
        }
        data = next
    }
}

@MainActor
struct AppStoreTests {
    @Test func libraryTogglesPersistRenameAndReset() async throws {
        let disk = ControlledStorage(StoredData(libraryText: "pushups\nplank\ndead hang", snacks: []))
        let store = AppStore(persistence: disk)
        await store.load()
        store.toggleLibraryPreference(\.isMuted, keys: ["plank", "dead hang"])
        store.toggleLibraryPreference(\.isBoosted, keys: ["plank"])
        #expect(store.exercises == ["pushups"])
        store.setLibraryText("pushups\nside plank\ndead hang")
        store.flushLibrary()
        await store.waitForWrites()
        let restored = AppStore(persistence: disk)
        await restored.load()
        #expect(restored.data.exercisePreferences["side plank"] == ExercisePreferences(isMuted: true, isBoosted: true))
        #expect(restored.exercises == ["pushups"])
        restored.toggleLibraryPreference(\.isMuted, keys: ["side plank", "dead hang"])
        #expect(restored.exercises == ["pushups", "side plank", "dead hang"])
        #expect(restored.data.exercisePreferences["side plank"]?.isBoosted == true)
        try await restored.replaceData(with: .seed)
        #expect(restored.data.exercisePreferences.isEmpty)
        #expect(restored.exercises == LibraryParser.parse(SeedLibrary.text))
    }

    @Test func queuedEditsSaveTheMostRecentSnapshot() async {
        let disk = ControlledStorage()
        let store = AppStore(persistence: disk)
        await store.load()
        store.setLibraryText("a")
        store.flushLibrary()
        store.setLibraryText("b\nc")
        store.flushLibrary()
        await store.waitForWrites()
        #expect(await disk.load().libraryText == "b\nc")
        #expect(!store.hasUnsavedChanges)
    }

    @Test func failedCompletionCanRetryWithoutDuplicatingSnack() async throws {
        let disk = ControlledStorage()
        let store = AppStore(persistence: disk)
        await store.load()
        store.prepareSession(exercises: ["pushups"])
        store.startOrReconcile()
        await store.waitForWrites()
        let session = try #require(store.session)
        await disk.failNextSave()
        store.skip(expectedRevision: session.engine.revision)
        await store.waitForWrites()
        #expect(store.session?.engine.phase == .finishing)
        #expect(store.data.snacks.count == 1)
        #expect(await disk.load().snacks.isEmpty)
        #expect(store.storageIssue != nil)
        store.retrySave()
        await store.waitForWrites()
        #expect(store.session == nil)
        #expect(await disk.load().snacks.count == 1)
        #expect(await disk.load().activeSession == nil)
        #expect(store.recentSnackID == session.id)
    }

    @Test func replacementFailureDoesNotPublishOrEraseData() async throws {
        let original = StoredData(libraryText: "mine", snacks: [])
        let disk = ControlledStorage(original)
        let store = AppStore(persistence: disk)
        await store.load()
        await disk.failNextSave()
        await #expect(throws: (any Error).self) { try await store.replaceData(with: .seed) }
        #expect(store.data == original)
        #expect(await disk.load() == original)
        try await store.replaceData(with: .seed)
        #expect(store.data == .seed)
    }

    @Test func cancelAndKeepRestorePriorPauseState() async throws {
        let disk = ControlledStorage()
        let store = AppStore(persistence: disk)
        await store.load()
        store.prepareSession(exercises: ["pushups"])
        store.startOrReconcile()
        let session = try #require(store.session)
        store.beginCancellation()
        #expect(session.engine.phase == .paused)
        store.keepSession()
        #expect(session.engine.phase == .running)
        store.togglePause(expectedRevision: session.engine.revision)
        store.beginCancellation()
        store.keepSession()
        #expect(session.engine.phase == .paused)
        store.beginCancellation()
        store.cancelSession()
        await store.waitForWrites()
        #expect(store.session == nil)
        #expect(await disk.load().snacks.isEmpty)
        #expect(await disk.load().activeSession == nil)
    }

    @Test func expiredSessionIsRecoveredAndCompletedOnlyOnce() async throws {
        let id = UUID()
        let checkpoint = SessionCheckpoint(
            id: id, exercises: ["pushups"], index: 0, phase: .running,
            deadline: Date().addingTimeInterval(-15), remaining: 30
        )
        let disk = ControlledStorage(StoredData(libraryText: "pushups", snacks: [], activeSession: checkpoint))
        let store = AppStore(persistence: disk)
        await store.load()
        await store.waitForWrites()
        #expect(store.data.snacks.map(\.id) == [id])
        let completion = try #require(store.data.snacks.first?.completedAt)
        #expect(abs(completion.timeIntervalSince(try #require(checkpoint.deadline))) < 0.001)
        let reopened = AppStore(persistence: disk)
        await reopened.load()
        #expect(reopened.session == nil)
        #expect(reopened.data.snacks.count == 1)
    }
}
