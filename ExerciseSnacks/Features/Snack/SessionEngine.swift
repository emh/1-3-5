import Foundation

struct SessionTime: Sendable {
    let elapsed: TimeInterval
    let date: Date
}

enum SessionClock {
    private static let origin = ContinuousClock.now

    static func now() -> SessionTime {
        let components = origin.duration(to: .now).components
        return SessionTime(
            elapsed: Double(components.seconds) + Double(components.attoseconds) / 1e18,
            date: Date()
        )
    }
}

enum SessionPhase: String, Codable, Sendable {
    case ready, countingDown, countdownPaused, running, paused, finishing, cancelled

    var isCountingDown: Bool { self == .countingDown || self == .countdownPaused }
    var isPaused: Bool { self == .paused || self == .countdownPaused }
    var isTicking: Bool { self == .running || self == .countingDown }
}

struct SessionCheckpoint: Codable, Equatable, Sendable {
    let id: UUID
    let exercises: [String]
    let index: Int
    let phase: SessionPhase
    let deadline: Date?
    let remaining: TimeInterval
}

/// Pure timer logic. All events carry a clock sample, making suspension and races testable.
struct SessionEngine: Equatable, Sendable {
    let id: UUID
    let exercises: [String]
    private(set) var index = 0
    private(set) var phase: SessionPhase = .ready
    private(set) var revision = 0
    private(set) var completedAt: Date?
    private var deadline: TimeInterval?
    private var frozenRemaining: TimeInterval = 10

    init(id: UUID = UUID(), exercises: [String]) {
        self.id = id
        self.exercises = exercises
    }

    init(checkpoint: SessionCheckpoint, at time: SessionTime) {
        id = checkpoint.id
        exercises = checkpoint.exercises
        index = checkpoint.index
        phase = checkpoint.phase
        frozenRemaining = checkpoint.remaining
        if let savedDeadline = checkpoint.deadline {
            deadline = time.elapsed + savedDeadline.timeIntervalSince(time.date)
        }
        reconcile(at: time)
    }

    var exercise: String { exercises[index] }

    var nextExercise: String? {
        let nextIndex = phase.isCountingDown || phase == .ready ? index : index + 1
        return exercises.indices.contains(nextIndex) ? exercises[nextIndex] : nil
    }

    func remaining(at time: SessionTime) -> TimeInterval {
        switch phase {
        case .countingDown, .running: max(0, (deadline ?? time.elapsed) - time.elapsed)
        case .ready, .countdownPaused, .paused: frozenRemaining
        case .finishing, .cancelled: 0
        }
    }

    mutating func start(at time: SessionTime) {
        guard phase == .ready else { return }
        phase = .countingDown
        deadline = time.elapsed + 10
        revision += 1
    }

    mutating func reconcile(at time: SessionTime) {
        while phase.isTicking, let end = deadline, time.elapsed >= end {
            if phase == .countingDown {
                beginExercises(at: end)
            } else {
                advance(at: end, completionDate: time.date.addingTimeInterval(end - time.elapsed))
            }
        }
    }

    mutating func pause(at time: SessionTime) {
        reconcile(at: time)
        guard phase.isTicking else { return }
        frozenRemaining = remaining(at: time)
        deadline = nil
        phase = phase == .countingDown ? .countdownPaused : .paused
        revision += 1
    }

    mutating func resume(at time: SessionTime) {
        guard phase.isPaused else { return }
        deadline = time.elapsed + frozenRemaining
        phase = phase == .countdownPaused ? .countingDown : .running
        revision += 1
    }

    mutating func togglePause(expectedRevision: Int, at time: SessionTime) {
        guard revision == expectedRevision else { return }
        if phase.isPaused { resume(at: time) } else { pause(at: time) }
    }

    mutating func skip(expectedRevision: Int, at time: SessionTime) {
        guard revision == expectedRevision else { return }
        reconcile(at: time)
        // A deadline that won this race already advanced this exercise.
        guard revision == expectedRevision, phase.isTicking || phase.isPaused else { return }
        if phase.isCountingDown {
            beginExercises(at: time.elapsed)
        } else {
            advance(at: time.elapsed, completionDate: time.date)
        }
    }

    mutating func cancel() {
        guard phase != .finishing, phase != .cancelled else { return }
        phase = .cancelled
        deadline = nil
        revision += 1
    }

    func checkpoint(at time: SessionTime) -> SessionCheckpoint? {
        guard phase.isTicking || phase.isPaused else { return nil }
        return SessionCheckpoint(
            id: id, exercises: exercises, index: index, phase: phase,
            deadline: deadline.map { time.date.addingTimeInterval($0 - time.elapsed) },
            remaining: remaining(at: time)
        )
    }

    private mutating func beginExercises(at time: TimeInterval) {
        phase = phase.isPaused ? .paused : .running
        frozenRemaining = 60
        deadline = phase.isTicking ? time + 60 : nil
        revision += 1
    }

    private mutating func advance(at end: TimeInterval, completionDate: Date) {
        revision += 1
        if index == exercises.count - 1 {
            phase = .finishing
            completedAt = completionDate
            deadline = nil
            frozenRemaining = 0
        } else {
            index += 1
            frozenRemaining = 60
            deadline = phase == .running ? end + 60 : nil
        }
    }
}
