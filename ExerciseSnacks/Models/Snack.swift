import Foundation

struct Snack: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let completedAt: Date
    let exercises: [String]

    var durationLabel: String { "\(exercises.count)m" }
}

enum SeedLibrary {
    static let text = """
    pushups
    air squats
    split squats
    cossack squats
    situps
    plank
    side plank
    dead hang
    rope flow
    indian club circles
    steel club mills
    kb swings
    kb goblet squats
    kb snatches
    kb clean & presses
    kb around the worlds
    kb halos
    rolling getups
    underswitches
    jump rope
    kick throughs
    horse stance
    iso lunge
    iso calf raise
    deep squat
    kb rows
    glute bridges
    suitcase carries
    """
}
