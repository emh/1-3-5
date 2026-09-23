import Foundation
import Observation

struct StorageIssue: Identifiable {
    let id = UUID()
    let message: String
}

@MainActor @Observable
final class AppStore {
    private(set) var data = StoredData.seed
    private(set) var exercises = LibraryParser.parse(SeedLibrary.text)
    private(set) var historySections: [HistorySection] = []
    private(set) var isLoaded = false
    private(set) var isLoading = false
    private(set) var isReplacing = false
    private(set) var session: SnackSession?
    private(set) var pendingWrites = 0
    var loadError: String?
    var storageIssue: StorageIssue?
    var recentSnackID: UUID?
    var queuedExercises: [String]?

    @ObservationIgnored private let persistence: any DataPersistence
    @ObservationIgnored private var writeTask: Task<Void, Never>?
    @ObservationIgnored private var libraryDebounce: Task<Void, Never>?
    @ObservationIgnored private var writeRevision = 0
    @ObservationIgnored private var savedRevision = 0

    var isSaving: Bool { pendingWrites > 0 }
    var hasUnsavedChanges: Bool { savedRevision < writeRevision }

    init(persistence: any DataPersistence = LocalDataStore()) {
        self.persistence = persistence
    }

    func load() async {
        guard !isLoaded, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            data = try await persistence.load()
            refreshExercises()
            refreshHistory()
            isLoaded = true
            loadError = nil
            if let checkpoint = data.activeSession {
                let now = SessionClock.now()
                session = SnackSession(engine: SessionEngine(checkpoint: checkpoint, at: now), at: now)
                sessionChanged(at: now)
            }
        } catch {
            loadError = error.localizedDescription
        }
    }

    func setLibraryText(_ text: String) {
        guard isLoaded, !isReplacing else { return }
        data.exercisePreferences = LibraryLines.preferences(afterEditing: data.libraryText, to: text, previous: data.exercisePreferences)
        data.libraryText = text
        libraryChanged()
    }

    func toggleLibraryPreference(_ preference: WritableKeyPath<ExercisePreferences, Bool>, keys: Set<String>) {
        guard isLoaded, !isReplacing, !keys.isEmpty else { return }
        let validKeys = keys.intersection(LibraryParser.parse(data.libraryText).map(LibraryParser.key))
        let enable = !validKeys.allSatisfy { (data.exercisePreferences[$0] ?? ExercisePreferences())[keyPath: preference] }
        for key in validKeys {
            var value = data.exercisePreferences[key] ?? ExercisePreferences()
            value[keyPath: preference] = enable
            data.exercisePreferences[key] = value.isDefault ? nil : value
        }
        libraryChanged()
    }

    private func refreshExercises() {
        exercises = SnackGenerator.eligible(library: LibraryParser.parse(data.libraryText), preferences: data.exercisePreferences)
    }

    private func libraryChanged() {
        refreshExercises()
        libraryDebounce?.cancel()
        libraryDebounce = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(400)) } catch { return }
            guard let self else { return }
            self.libraryDebounce = nil
            self.persist()
        }
    }

    func flushLibrary() {
        guard libraryDebounce != nil else { return }
        libraryDebounce?.cancel()
        libraryDebounce = nil
        persist()
    }

    func refreshHistory(now: Date = Date()) {
        historySections = HistoryGrouping.sections(for: data.snacks, now: now)
    }

    func prepareSession(exercises: [String]) {
        guard isLoaded, !isReplacing, session == nil, SnackGenerator.sizes.contains(exercises.count) else { return }
        session = SnackSession(engine: SessionEngine(exercises: exercises))
    }

    func startQueuedSession() {
        guard let exercises = queuedExercises else { return }
        queuedExercises = nil
        prepareSession(exercises: exercises)
    }

    func startOrReconcile() {
        guard let session else { return }
        let now = SessionClock.now()
        let changed = session.update(at: now) {
            if $0.phase == .ready { $0.start(at: now) } else { $0.reconcile(at: now) }
        }
        if changed { sessionChanged(at: now) }
    }

    func tick() {
        guard let session, !session.isConfirmingCancellation else { return }
        let now = SessionClock.now()
        if session.update(at: now, { $0.reconcile(at: now) }) {
            sessionChanged(at: now)
        }
    }

    func togglePause(expectedRevision: Int) {
        mutateSession { engine, now in engine.togglePause(expectedRevision: expectedRevision, at: now) }
    }

    func skip(expectedRevision: Int) {
        mutateSession { engine, now in engine.skip(expectedRevision: expectedRevision, at: now) }
    }

    func beginCancellation() {
        guard let session, !session.isConfirmingCancellation else { return }
        let now = SessionClock.now()
        session.update(at: now) { $0.reconcile(at: now) }
        guard session.engine.phase == .running || session.engine.phase == .paused else {
            sessionChanged(at: now)
            return
        }
        session.resumeAfterConfirmation = session.engine.phase == .running
        session.update(at: now) { $0.pause(at: now) }
        session.isConfirmingCancellation = true
        sessionChanged(at: now)
    }

    func keepSession() {
        guard let session else { return }
        session.isConfirmingCancellation = false
        if session.resumeAfterConfirmation {
            let now = SessionClock.now()
            session.update(at: now) { $0.resume(at: now) }
            sessionChanged(at: now)
        }
    }

    func cancelSession() {
        guard let session else { return }
        session.isConfirmingCancellation = false
        let now = SessionClock.now()
        session.update(at: now) { $0.cancel() }
        sessionChanged(at: now)
    }

    func backgrounded() {
        flushLibrary()
        guard let session, session.engine.phase == .running || session.engine.phase == .paused else { return }
        let now = SessionClock.now()
        session.update(at: now) { $0.reconcile(at: now) }
        sessionChanged(at: now)
    }

    func retrySave() {
        storageIssue = nil
        persist()
    }

    func waitForWrites() async {
        await writeTask?.value
    }

    func replaceData(with replacement: StoredData) async throws {
        guard !isReplacing else { return }
        isReplacing = true
        defer { isReplacing = false }
        flushLibrary()
        await waitForWrites()
        try await persistence.save(replacement)
        data = replacement
        refreshExercises()
        session = nil
        recentSnackID = nil
        refreshHistory()
        writeRevision += 1
        savedRevision = writeRevision
        storageIssue = nil
        loadError = nil
        isLoaded = true
    }

    private func mutateSession(_ mutation: (inout SessionEngine, SessionTime) -> Void) {
        guard let session, !session.isConfirmingCancellation else { return }
        let now = SessionClock.now()
        if session.update(at: now, { mutation(&$0, now) }) { sessionChanged(at: now) }
    }

    private func sessionChanged(at time: SessionTime) {
        guard let session else { return }
        switch session.engine.phase {
        case .ready: return
        case .running, .paused:
            data.activeSession = session.engine.checkpoint(at: time)
        case .finishing:
            guard !session.completionRequested, let completedAt = session.engine.completedAt else { return }
            session.completionRequested = true
            if !data.snacks.contains(where: { $0.id == session.id }) {
                data.snacks.append(Snack(id: session.id, completedAt: completedAt, exercises: session.engine.exercises))
                data.snacks.sort { $0.completedAt > $1.completedAt }
                refreshHistory()
            }
            data.activeSession = nil
        case .cancelled:
            data.activeSession = nil
        }
        persist()
    }

    private func persist() {
        let snapshot = data
        writeRevision += 1
        let revision = writeRevision
        let previous = writeTask
        pendingWrites += 1
        writeTask = Task {
            await previous?.value
            defer { pendingWrites -= 1 }
            do {
                try await persistence.save(snapshot)
                savedRevision = revision
                if revision == writeRevision {
                    storageIssue = nil
                    if let session, snapshot.activeSession == nil {
                        if session.engine.phase == .finishing, snapshot.snacks.contains(where: { $0.id == session.id }) {
                            recentSnackID = session.id
                            self.session = nil
                        } else if session.engine.phase == .cancelled {
                            self.session = nil
                        }
                    }
                }
            } catch {
                if revision == writeRevision {
                    storageIssue = StorageIssue(message: "Your changes are still here, but could not be saved. \(error.localizedDescription)")
                }
            }
        }
    }
}
