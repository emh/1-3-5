import Foundation
import Testing
@testable import ExerciseSnacks

struct SessionEngineTests {
    private let epoch = Date(timeIntervalSince1970: 1_800_000_000)
    private func time(_ seconds: Double, wallShift: Double = 0) -> SessionTime {
        SessionTime(elapsed: seconds, date: epoch.addingTimeInterval(seconds + wallShift))
    }

    private func startExercises(_ engine: inout SessionEngine) {
        engine.start(at: time(-10))
        engine.reconcile(at: time(0))
    }

    @Test func preparationGetsTenSecondsBeforeTheFirstFullMinute() {
        var engine = SessionEngine(exercises: ["pushups", "plank", "squats"])
        engine.start(at: time(0))
        #expect(engine.phase == .countingDown)
        #expect(engine.remaining(at: time(0)) == 10)
        #expect(engine.nextExercise == "pushups")
        engine.reconcile(at: time(9.99))
        #expect(engine.phase == .countingDown)
        #expect(engine.index == 0)
        engine.reconcile(at: time(10))
        #expect(engine.phase == .running)
        #expect(engine.remaining(at: time(10)) == 60)
        #expect(engine.exercise == "pushups")
        #expect(engine.nextExercise == "plank")
        engine.reconcile(at: time(70))
        #expect(engine.index == 1)
        #expect(engine.remaining(at: time(70)) == 60)
        engine.reconcile(at: time(130))
        #expect(engine.nextExercise == nil)
        engine.reconcile(at: time(190))
        #expect(engine.completedAt == epoch.addingTimeInterval(190))
    }

    @Test func preparationPauseResumeAndSkipPreserveTheFirstExercise() {
        var engine = SessionEngine(exercises: ["pushups"])
        engine.start(at: time(0))
        engine.pause(at: time(3.25))
        #expect(engine.phase == .countdownPaused)
        #expect(engine.remaining(at: time(100)) == 6.75)
        engine.resume(at: time(100))
        engine.reconcile(at: time(106.75))
        #expect(engine.phase == .running)
        #expect(engine.index == 0)
        #expect(engine.remaining(at: time(106.75)) == 60)

        var skipped = SessionEngine(exercises: ["pushups"])
        skipped.start(at: time(0))
        skipped.pause(at: time(2))
        skipped.skip(expectedRevision: skipped.revision, at: time(100))
        #expect(skipped.phase == .paused)
        #expect(skipped.index == 0)
        #expect(skipped.remaining(at: time(100)) == 60)
        #expect(skipped.completedAt == nil)
    }

    @Test func skipAtPreparationDeadlineDoesNotSkipTheFirstExercise() {
        var engine = SessionEngine(exercises: ["pushups"])
        engine.start(at: time(0))
        let revision = engine.revision
        engine.skip(expectedRevision: revision, at: time(10))
        #expect(engine.phase == .running)
        #expect(engine.index == 0)
        #expect(engine.remaining(at: time(10)) == 60)
    }

    @Test(arguments: [false, true])
    func preparationCheckpointRoundTripsAndRestores(paused: Bool) throws {
        var engine = SessionEngine(exercises: ["pushups"])
        engine.start(at: time(0))
        if paused { engine.pause(at: time(3)) }
        let checkpoint = try #require(engine.checkpoint(at: time(3)))
        let data = StoredData(libraryText: "pushups", snacks: [], activeSession: checkpoint)
        try DataValidation.stored(data)
        let decoded = try JSONCodec.decoder().decode(StoredData.self, from: JSONCodec.encoder().encode(data))
        #expect(decoded == data)
        let restored = SessionEngine(checkpoint: try #require(decoded.activeSession), at: time(15))
        #expect(restored.phase == (paused ? .countdownPaused : .running))
        #expect(restored.remaining(at: time(15)) == (paused ? 7 : 55))
        #expect(restored.index == 0)
    }

    @Test func backgroundCatchUpIncludesPreparationAndKeepsTheOriginalCompletionDate() throws {
        var engine = SessionEngine(exercises: ["pushups", "plank", "squats"])
        engine.start(at: time(0))
        let checkpoint = try #require(engine.checkpoint(at: time(2)))
        let restored = SessionEngine(checkpoint: checkpoint, at: time(250))
        #expect(restored.phase == .finishing)
        #expect(restored.completedAt == epoch.addingTimeInterval(190))
        engine.cancel()
        engine.reconcile(at: time(250))
        #expect(engine.completedAt == nil)
    }

    @Test @MainActor func feedbackFiresOnceForEachCountdownSecondAndEachMinuteStart() {
        var engine = SessionEngine(exercises: ["pushups", "plank", "squats"])
        engine.start(at: time(0))
        let session = SnackSession(engine: engine, at: time(0))
        var cues: [(Double, TimerCue)] = []
        for step in 1...1900 {
            let seconds = Double(step) / 10
            let previous = session.feedbackState
            session.update(at: time(seconds)) { $0.reconcile(at: time(seconds)) }
            if let cue = session.feedbackState.cue(after: previous) { cues.append((seconds, cue)) }
        }
        #expect(cues.filter { $0.1 == .countdown }.map(\.0) == [7, 8, 9, 67, 68, 69, 127, 128, 129, 187, 188, 189])
        #expect(cues.filter { $0.1 == .start }.map(\.0) == [10, 70, 130])
    }

    @Test func feedbackDoesNotRepeatOnPauseOrReplayMissedSeconds() {
        let running = TimerFeedbackState(phase: .running, index: 0, seconds: 3)
        let paused = TimerFeedbackState(phase: .paused, index: 0, seconds: 3)
        #expect(paused.cue(after: running) == nil)
        #expect(running.cue(after: paused) == nil)
        #expect(running.cue(after: running) == nil)
        #expect(running.cue(after: TimerFeedbackState(phase: .running, index: 0, seconds: 20)) == nil)
        #expect(TimerFeedbackState(phase: .running, index: 1, seconds: 45)
            .cue(after: TimerFeedbackState(phase: .running, index: 0, seconds: 1)) == nil)
        #expect(TimerFeedbackState(phase: .running, index: 1, seconds: 60)
            .cue(after: TimerFeedbackState(phase: .paused, index: 1, seconds: 60)) == .start)
    }

    @Test(arguments: [1, 3, 5])
    func completesAtTheExactDeadline(count: Int) {
        var engine = SessionEngine(exercises: (1...count).map { "exercise \($0)" })
        startExercises(&engine)
        #expect(engine.remaining(at: time(0)) == 60)
        engine.reconcile(at: time(Double(count * 60) - 0.01))
        #expect(engine.phase == .running)
        #expect(engine.index == count - 1)
        engine.reconcile(at: time(Double(count * 60)))
        #expect(engine.phase == .finishing)
        #expect(engine.completedAt == epoch.addingTimeInterval(Double(count * 60)))
        let revision = engine.revision
        engine.reconcile(at: time(1000))
        #expect(engine.revision == revision)
    }

    @Test func backgroundCatchUpDoesNotResetEachMissedMinute() {
        var engine = SessionEngine(exercises: ["a", "b", "c"])
        startExercises(&engine)
        engine.reconcile(at: time(130))
        #expect(engine.index == 2)
        #expect(engine.remaining(at: time(130)) == 50)
        engine.reconcile(at: time(900))
        #expect(engine.completedAt == epoch.addingTimeInterval(180))
    }

    @Test func pausePreservesFractionalTimeAndPausedSkipStaysPaused() {
        var engine = SessionEngine(exercises: ["a", "b", "c"])
        startExercises(&engine)
        engine.pause(at: time(15.25))
        engine.reconcile(at: time(800))
        #expect(engine.remaining(at: time(800)) == 44.75)
        engine.resume(at: time(800))
        #expect(engine.remaining(at: time(810)) == 34.75)
        engine.pause(at: time(810))
        engine.skip(expectedRevision: engine.revision, at: time(900))
        #expect(engine.index == 1)
        #expect(engine.phase == .paused)
        #expect(engine.remaining(at: time(9999)) == 60)
    }

    @Test func staleSkipCannotSkipTheNextExerciseAfterExpiry() {
        var engine = SessionEngine(exercises: ["a", "b", "c"])
        startExercises(&engine)
        let revision = engine.revision
        engine.skip(expectedRevision: revision, at: time(60))
        #expect(engine.index == 1)
        engine.skip(expectedRevision: revision, at: time(60.1))
        #expect(engine.index == 1)
        #expect(engine.remaining(at: time(60)) == 60)
    }

    @Test func runningSkipStartsFreshMinuteAndFinalSkipCompletes() {
        var engine = SessionEngine(exercises: ["a", "b", "c"])
        startExercises(&engine)
        engine.skip(expectedRevision: engine.revision, at: time(10))
        #expect(engine.remaining(at: time(10)) == 60)
        engine.skip(expectedRevision: engine.revision, at: time(12))
        engine.skip(expectedRevision: engine.revision, at: time(14))
        #expect(engine.phase == .finishing)
        #expect(engine.completedAt == epoch.addingTimeInterval(14))
        #expect(engine.exercises == ["a", "b", "c"])
    }

    @Test func restoringCheckpointCatchesUpWithANewMonotonicOrigin() throws {
        var engine = SessionEngine(exercises: ["a", "b", "c"])
        startExercises(&engine)
        let checkpoint = try #require(engine.checkpoint(at: time(20)))
        var restored = SessionEngine(checkpoint: checkpoint, at: SessionTime(elapsed: 0, date: epoch.addingTimeInterval(130)))
        #expect(restored.index == 2)
        #expect(restored.remaining(at: SessionTime(elapsed: 0, date: epoch)) == 50)
        restored.reconcile(at: SessionTime(elapsed: 1000, date: epoch.addingTimeInterval(1130)))
        #expect(restored.completedAt == epoch.addingTimeInterval(180))
    }

    @Test func pausedCheckpointNeverCatchesUp() throws {
        var engine = SessionEngine(exercises: ["a"])
        startExercises(&engine)
        engine.pause(at: time(10))
        let checkpoint = try #require(engine.checkpoint(at: time(10)))
        let restored = SessionEngine(checkpoint: checkpoint, at: time(10000))
        #expect(restored.phase == .paused)
        #expect(restored.remaining(at: time(20000)) == 50)
    }

    @Test func wallClockChangesDoNotChangeElapsedTime() {
        var engine = SessionEngine(exercises: ["a"])
        startExercises(&engine)
        engine.reconcile(at: time(15, wallShift: 3600))
        #expect(engine.remaining(at: time(15, wallShift: -3600)) == 45)
        #expect(engine.phase == .running)
    }

    @Test func cancelNeverProducesACompletion() {
        var engine = SessionEngine(exercises: ["a"])
        startExercises(&engine)
        engine.cancel()
        engine.reconcile(at: time(500))
        #expect(engine.phase == .cancelled)
        #expect(engine.completedAt == nil)
        #expect(engine.checkpoint(at: time(500)) == nil)
    }
}
