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
