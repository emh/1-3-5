import Foundation

enum LibraryParser {
    static func key(for name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .precomposedStringWithCanonicalMapping
            .lowercased(with: Locale(identifier: "en_US_POSIX"))
    }

    static func parse(_ text: String) -> [String] {
        var seen = Set<String>()
        return text.components(separatedBy: .newlines).compactMap { line in
            let name = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, seen.insert(key(for: name)).inserted else { return nil }
            return name
        }
    }
}

enum SnackGenerator {
    static let sizes = [1, 3, 5]

    static func generate<R: RandomNumberGenerator>(
        count: Int, library: [String], preferences: [String: ExercisePreferences] = [:], using random: inout R
    ) -> [String]? {
        var unique = eligible(library: library, preferences: preferences)
        guard sizes.contains(count), unique.count >= count else { return nil }
        return (0..<count).map { _ in
            let index = weightedIndex(in: unique, preferences: preferences, using: &random)
            return unique.remove(at: index)
        }
    }

    static func eligible(library: [String], preferences: [String: ExercisePreferences]) -> [String] {
        LibraryParser.parse(library.joined(separator: "\n")).filter {
            preferences[LibraryParser.key(for: $0)]?.isMuted != true
        }
    }

    static func candidates(library: [String], current: [String], preferences: [String: ExercisePreferences] = [:]) -> [String] {
        let excluded = Set(current.map(LibraryParser.key))
        return eligible(library: library, preferences: preferences).filter { !excluded.contains(LibraryParser.key(for: $0)) }
    }

    static func reroll<R: RandomNumberGenerator>(
        at index: Int, current: [String], library: [String], preferences: [String: ExercisePreferences] = [:], using random: inout R
    ) -> [String]? {
        let options = candidates(library: library, current: current, preferences: preferences)
        guard current.indices.contains(index), !options.isEmpty else { return nil }
        let replacement = options[weightedIndex(in: options, preferences: preferences, using: &random)]
        var result = current
        result[index] = replacement
        return result
    }

    private static func weightedIndex<R: RandomNumberGenerator>(
        in names: [String], preferences: [String: ExercisePreferences], using random: inout R
    ) -> Int {
        let weights = names.map { preferences[LibraryParser.key(for: $0)]?.weight ?? 1 }
        var ticket = Int.random(in: 0..<weights.reduce(0, +), using: &random)
        for index in names.indices {
            if ticket < weights[index] { return index }
            ticket -= weights[index]
        }
        preconditionFailure("A weighted draw must select an eligible exercise")
    }
}
