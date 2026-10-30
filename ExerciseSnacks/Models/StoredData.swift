import Foundation

struct StoredData: Codable, Equatable, Sendable {
    var version = 1
    var libraryText: String
    var snacks: [Snack]
    var activeSession: SessionCheckpoint?
    var exercisePreferences: [String: ExercisePreferences] = [:]
    var snackSchedule = SnackSchedule()

    /// A saved record is a set; each exercise in that set counts as one snack.
    var widgetSnapshot: SnackWidgetSnapshot {
        SnackWidgetSnapshot(
            completions: snacks.flatMap { Array(repeating: $0.completedAt, count: $0.exercises.count) },
            schedule: snackSchedule
        )
    }

    static let seed = StoredData(libraryText: SeedLibrary.text, snacks: [])
}

extension StoredData {
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        version = try values.decode(Int.self, forKey: .version)
        libraryText = try values.decode(String.self, forKey: .libraryText)
        snacks = try values.decode([Snack].self, forKey: .snacks)
        activeSession = try values.decodeIfPresent(SessionCheckpoint.self, forKey: .activeSession)
        exercisePreferences = try values.decodeIfPresent([String: ExercisePreferences].self, forKey: .exercisePreferences) ?? [:]
        snackSchedule = try values.decodeIfPresent(SnackSchedule.self, forKey: .snackSchedule) ?? SnackSchedule()
    }
}

struct ExportPayload: Codable, Equatable, Sendable {
    var version = 1
    let library: [String]
    let snacks: [Snack]
    let exercisePreferences: [String: ExercisePreferences]
    let snackSchedule: SnackSchedule

    init(data: StoredData) {
        library = LibraryParser.parse(data.libraryText)
        snacks = data.snacks
        exercisePreferences = data.exercisePreferences
        snackSchedule = data.snackSchedule
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        version = try values.decode(Int.self, forKey: .version)
        library = try values.decode([String].self, forKey: .library)
        snacks = try values.decode([Snack].self, forKey: .snacks)
        exercisePreferences = try values.decodeIfPresent([String: ExercisePreferences].self, forKey: .exercisePreferences) ?? [:]
        snackSchedule = try values.decodeIfPresent(SnackSchedule.self, forKey: .snackSchedule) ?? SnackSchedule()
    }

    func importedData() throws -> StoredData {
        guard version == 1 else { throw DataError.unsupportedVersion }
        guard snackSchedule.isValid else { throw DataError.invalidSchedule }
        try DataValidation.names(library, allowDuplicates: true)
        try DataValidation.snacks(snacks)
        try DataValidation.preferences(exercisePreferences, library: library)
        return StoredData(
            libraryText: LibraryParser.parse(library.joined(separator: "\n")).joined(separator: "\n"),
            snacks: snacks.sorted { $0.completedAt > $1.completedAt },
            exercisePreferences: exercisePreferences,
            snackSchedule: snackSchedule
        )
    }
}

enum DataError: LocalizedError {
    case unsupportedVersion, invalidExercises, invalidHistory, invalidSession, invalidPreferences, invalidSchedule

    var errorDescription: String? {
        switch self {
        case .invalidSchedule: "The snack schedule contains invalid values."
        case .unsupportedVersion: "This file uses an unsupported data version."
        case .invalidExercises: "Exercise names must be non-empty, single lines of text."
        case .invalidHistory: "This file contains invalid or duplicate snack records."
        case .invalidSession: "The saved snack could not be restored."
        case .invalidPreferences: "Exercise preferences must refer to exercises in the library."
        }
    }
}

enum DataValidation {
    static func preferences(_ preferences: [String: ExercisePreferences], library: [String]) throws {
        let keys = Set(library.map(LibraryParser.key))
        guard preferences.keys.allSatisfy({ !$0.isEmpty && $0 == LibraryParser.key(for: $0) && keys.contains($0) })
        else { throw DataError.invalidPreferences }
    }

    static func names(_ exercises: [String], allowDuplicates: Bool = false) throws {
        guard exercises.allSatisfy({
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && $0.rangeOfCharacter(from: .newlines) == nil
        }) else { throw DataError.invalidExercises }
        if !allowDuplicates && Set(exercises.map(LibraryParser.key)).count != exercises.count {
            throw DataError.invalidHistory
        }
    }

    static func snacks(_ snacks: [Snack]) throws {
        guard Set(snacks.map(\.id)).count == snacks.count else { throw DataError.invalidHistory }
        for snack in snacks {
            guard SnackGenerator.sizes.contains(snack.exercises.count),
                  snack.completedAt.timeIntervalSince1970.isFinite
            else { throw DataError.invalidHistory }
            try names(snack.exercises)
        }
    }

    static func stored(_ data: StoredData) throws {
        guard data.snackSchedule.isValid else { throw DataError.invalidSchedule }
        guard data.version == 1 else { throw DataError.unsupportedVersion }
        try preferences(data.exercisePreferences, library: LibraryParser.parse(data.libraryText))
        try snacks(data.snacks)
        if let session = data.activeSession {
            try names(session.exercises)
            guard SnackGenerator.sizes.contains(session.exercises.count),
                  session.exercises.indices.contains(session.index),
                  session.remaining.isFinite, (0...60).contains(session.remaining),
                  session.phase.isTicking || session.phase.isPaused,
                  session.phase.isTicking == (session.deadline != nil),
                  !session.phase.isCountingDown || (session.index == 0 && session.remaining <= 10),
                  !data.snacks.contains(where: { $0.id == session.id })
            else { throw DataError.invalidSession }
        }
    }
}

enum JSONCodec {
    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(date.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true)))
        }
        return encoder
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = try? Date(value, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)) { return date }
            guard let date = try? Date(value, strategy: Date.ISO8601FormatStyle()) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO-8601 date.")
            }
            return date
        }
        return decoder
    }

    static func importData(_ bytes: Data) throws -> StoredData {
        try decoder().decode(ExportPayload.self, from: bytes).importedData()
    }
}
