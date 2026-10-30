import Foundation
import Observation

@MainActor @Observable
final class SnackSession: Identifiable {
    nonisolated let id: UUID
    private(set) var engine: SessionEngine
    private(set) var secondsRemaining: Int
    var isConfirmingCancellation = false
    var resumeAfterConfirmation = false
    var completionRequested = false

    var timerText: String { String(format: "%02d:%02d", secondsRemaining / 60, secondsRemaining % 60) }
    var feedbackState: TimerFeedbackState {
        TimerFeedbackState(phase: engine.phase, index: engine.index, seconds: secondsRemaining)
    }

    init(engine: SessionEngine, at time: SessionTime = SessionClock.now()) {
        id = engine.id
        self.engine = engine
        secondsRemaining = Int(ceil(engine.remaining(at: time)))
    }

    @discardableResult
    func update(at time: SessionTime, _ mutation: (inout SessionEngine) -> Void) -> Bool {
        var next = engine
        mutation(&next)
        let changed = next != engine
        if changed { engine = next }
        secondsRemaining = Int(ceil(next.remaining(at: time)))
        return changed
    }
}

enum TimerCue { case countdown, start }

struct TimerFeedbackState: Equatable {
    let phase: SessionPhase
    let index: Int
    let seconds: Int

    func cue(after previous: Self) -> TimerCue? {
        guard phase.isTicking else { return nil }
        if phase == .running, seconds == 60,
           previous.phase.isCountingDown || previous.index != index
            || (previous.phase == .paused && previous.seconds == 60) {
            return .start
        }
        // Pausing/resuming or foreground catch-up must not replay missed beeps.
        if previous.phase == phase, previous.index == index,
           previous.seconds == seconds + 1, (1...3).contains(seconds) {
            return .countdown
        }
        return nil
    }
}
