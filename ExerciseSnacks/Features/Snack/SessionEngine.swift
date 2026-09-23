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
    case ready, running, paused, finishing, cancelled
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
    private var frozenRemaining: TimeInterval = 60

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

    func remaining(at time: SessionTime) -> TimeInterval {
        switch phase {
        case .running: max(0, (deadline ?? time.elapsed) - time.elapsed)
        case .ready, .paused: frozenRemaining
        case .finishing, .cancelled: 0
        }
    }

    mutating func start(at time: SessionTime) {
        guard phase == .ready else { return }
        phase = .running
        deadline = time.elapsed + 60
        revision += 1
    }

    mutating func reconcile(at time: SessionTime) {
        while phase == .running, let end = deadline, time.elapsed >= end {
            advance(at: end, completionDate: time.date.addingTimeInterval(end - time.elapsed))
        }
    }

    mutating func pause(at time: SessionTime) {
        reconcile(at: time)
        guard phase == .running else { return }
        frozenRemaining = remaining(at: time)
        deadline = nil
        phase = .paused
        revision += 1
    }

    mutating func resume(at time: SessionTime) {
        guard phase == .paused else { return }
        deadline = time.elapsed + frozenRemaining
        phase = .running
        revision += 1
    }

    mutating func togglePause(expectedRevision: Int, at time: SessionTime) {
        guard revision == expectedRevision else { return }
        if phase == .paused { resume(at: time) } else { pause(at: time) }
    }

    mutating func skip(expectedRevision: Int, at time: SessionTime) {
        guard revision == expectedRevision else { return }
        reconcile(at: time)
        // A deadline that won this race already advanced this exercise.
        guard revision == expectedRevision, phase == .running || phase == .paused else { return }
        advance(at: time.elapsed, completionDate: time.date)
    }

    mutating func cancel() {
        guard phase != .finishing, phase != .cancelled else { return }
        phase = .cancelled
        deadline = nil
        revision += 1
    }

    func checkpoint(at time: SessionTime) -> SessionCheckpoint? {
        guard phase == .running || phase == .paused else { return nil }
        return SessionCheckpoint(
            id: id, exercises: exercises, index: index, phase: phase,
            deadline: deadline.map { time.date.addingTimeInterval($0 - time.elapsed) },
            remaining: remaining(at: time)
        )
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

