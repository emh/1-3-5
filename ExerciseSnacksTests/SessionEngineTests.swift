import Foundation
import Testing
@testable import ExerciseSnacks

struct SessionEngineTests {
    private let epoch = Date(timeIntervalSince1970: 1_800_000_000)
    private func time(_ seconds: Double, wallShift: Double = 0) -> SessionTime {
        SessionTime(elapsed: seconds, date: epoch.addingTimeInterval(seconds + wallShift))
    }

    @Test(arguments: [1, 3, 5])
    func completesAtTheExactDeadline(count: Int) {
        var engine = SessionEngine(exercises: (1...count).map { "exercise \($0)" })
        engine.start(at: time(0))
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
        engine.start(at: time(0))
        engine.reconcile(at: time(130))
        #expect(engine.index == 2)
        #expect(engine.remaining(at: time(130)) == 50)
        engine.reconcile(at: time(900))
        #expect(engine.completedAt == epoch.addingTimeInterval(180))
    }

    @Test func pausePreservesFractionalTimeAndPausedSkipStaysPaused() {
        var engine = SessionEngine(exercises: ["a", "b", "c"])
        engine.start(at: time(0))
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
        engine.start(at: time(0))
        let revision = engine.revision
        engine.skip(expectedRevision: revision, at: time(60))
        #expect(engine.index == 1)
        engine.skip(expectedRevision: revision, at: time(60.1))
        #expect(engine.index == 1)
        #expect(engine.remaining(at: time(60)) == 60)
    }

    @Test func runningSkipStartsFreshMinuteAndFinalSkipCompletes() {
        var engine = SessionEngine(exercises: ["a", "b", "c"])
        engine.start(at: time(0))
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
        engine.start(at: time(0))
        let checkpoint = try #require(engine.checkpoint(at: time(20)))
        var restored = SessionEngine(checkpoint: checkpoint, at: SessionTime(elapsed: 0, date: epoch.addingTimeInterval(130)))
        #expect(restored.index == 2)
        #expect(restored.remaining(at: SessionTime(elapsed: 0, date: epoch)) == 50)
        restored.reconcile(at: SessionTime(elapsed: 1000, date: epoch.addingTimeInterval(1130)))
        #expect(restored.completedAt == epoch.addingTimeInterval(180))
    }

    @Test func pausedCheckpointNeverCatchesUp() throws {
        var engine = SessionEngine(exercises: ["a"])
        engine.start(at: time(0))
        engine.pause(at: time(10))
        let checkpoint = try #require(engine.checkpoint(at: time(10)))
        let restored = SessionEngine(checkpoint: checkpoint, at: time(10000))
        #expect(restored.phase == .paused)
        #expect(restored.remaining(at: time(20000)) == 50)
    }

    @Test func wallClockChangesDoNotChangeElapsedTime() {
        var engine = SessionEngine(exercises: ["a"])
        engine.start(at: time(0))
        engine.reconcile(at: time(15, wallShift: 3600))
        #expect(engine.remaining(at: time(15, wallShift: -3600)) == 45)
        #expect(engine.phase == .running)
    }

    @Test func cancelNeverProducesACompletion() {
        var engine = SessionEngine(exercises: ["a"])
        engine.start(at: time(0))
        engine.cancel()
        engine.reconcile(at: time(500))
        #expect(engine.phase == .cancelled)
        #expect(engine.completedAt == nil)
        #expect(engine.checkpoint(at: time(500)) == nil)
    }
}

