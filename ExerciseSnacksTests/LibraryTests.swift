import Foundation
import Testing
@testable import ExerciseSnacks

struct LibraryTests {
    @Test func mutedExercisesNeverEnterSnacksOrRerolls() throws {
        let library = ["pushups", "PUSHUPS", "plank", "dead hang", "air squats"]
        let preferences = ["pushups": ExercisePreferences(isMuted: true, isBoosted: true)]
        var random = SeededRandom()
        #expect(SnackGenerator.generate(count: 5, library: library, preferences: preferences, using: &random) == nil)
        for _ in 0..<100 {
            let snack = try #require(SnackGenerator.generate(count: 3, library: library, preferences: preferences, using: &random))
            #expect(Set(snack) == ["plank", "dead hang", "air squats"])
            let rerolled = try #require(SnackGenerator.reroll(at: 0, current: ["plank"], library: library, preferences: preferences, using: &random))
            #expect(["dead hang", "air squats"].contains(rerolled[0]))
        }
        #expect(SnackGenerator.generate(count: 1, library: ["pushups"], preferences: preferences, using: &random) == nil)
    }

    @Test func boostingDoublesDrawWeightWithoutDuplicates() throws {
        let preferences = ["a": ExercisePreferences(isBoosted: true)]
        var random = SeededRandom()
        var draws = 0
        var rerolls = 0
        for _ in 0..<6_000 {
            if SnackGenerator.generate(count: 1, library: ["a", "b"], preferences: preferences, using: &random) == ["a"] { draws += 1 }
            if SnackGenerator.reroll(at: 0, current: ["c"], library: ["a", "b", "c"], preferences: preferences, using: &random) == ["a"] { rerolls += 1 }
        }
        // A 2:1 draw should select a roughly two thirds of the time, for both paths.
        #expect((3_700...4_300).contains(draws))
        #expect((3_700...4_300).contains(rerolls))
        for _ in 0..<100 {
            let snack = try #require(SnackGenerator.generate(count: 3, library: ["a", "b", "c"], preferences: preferences, using: &random))
            #expect(Set(snack) == ["a", "b", "c"])
        }
    }

    @Test func selectionUsesWholeLinesAndUTF16Boundaries() {
        let text = "💪 pushups\r\nplank\n\ndead hang\n"
        let plank = (text as NSString).range(of: "plank")
        #expect(LibraryLines.selectedKeys(in: text, range: NSRange(location: 3, length: 0)).isEmpty)
        #expect(LibraryLines.selectedKeys(in: text, range: NSRange(location: 0, length: plank.location)) == ["💪 pushups"])
        #expect(LibraryLines.selectedKeys(in: text, range: NSRange(location: plank.location, length: plank.length + 1)) == ["plank"])
        #expect(LibraryLines.selectedKeys(in: text, range: NSRange(location: NSMaxRange(plank) + 1, length: 0)).isEmpty)
        #expect(LibraryLines.selectedKeys(in: text, range: NSRange(location: (text as NSString).length, length: 0)).isEmpty)
        #expect(LibraryLines.selectedKeys(in: text, range: NSRange(location: 0, length: (text as NSString).length)) == ["💪 pushups", "plank", "dead hang"])
    }

    @Test func selectionRequiresEveryExerciseNameToBeFullyHighlighted() {
        let text = "  air squats  \n\tplank\nkb clean & presses\n"
        let source = text as NSString
        let squats = source.range(of: "air squats")
        let plank = source.range(of: "plank")
        #expect(LibraryLines.selectedKeys(in: text, range: source.range(of: "air")).isEmpty)
        #expect(LibraryLines.selectedKeys(in: text, range: source.range(of: "squats")).isEmpty)
        #expect(LibraryLines.selectedKeys(in: text, range: source.range(of: "clean & presses")).isEmpty)
        #expect(LibraryLines.selectedKeys(in: text, range: squats) == ["air squats"])
        #expect(LibraryLines.selectedKeys(in: text, range: NSRange(location: 0, length: NSMaxRange(plank))) == ["air squats", "plank"])
        #expect(LibraryLines.selectedKeys(in: text, range: NSRange(location: squats.location + 1, length: NSMaxRange(plank) - squats.location - 1)).isEmpty)
        #expect(LibraryLines.selectedKeys(in: text, range: NSRange(location: 0, length: NSMaxRange(plank) - 1)).isEmpty)
        #expect(LibraryLines.selectedKeys(in: text, range: NSRange(location: NSMaxRange(squats), length: plank.location - NSMaxRange(squats))).isEmpty)
        #expect(LibraryLines.selectedKeys(in: text, range: NSRange(location: NSNotFound, length: 0)).isEmpty)
    }

    @Test func preferencesFollowRenamesAndReorderingWithoutLeakingToNewLines() {
        let options = ExercisePreferences(isMuted: true, isBoosted: true)
        let previous = ["plank": options]
        #expect(LibraryLines.preferences(afterEditing: "plank\npushups", to: "side plank\npushups", previous: previous) == ["side plank": options])
        #expect(LibraryLines.preferences(afterEditing: "plank\npushups", to: "pushups\nplank", previous: previous) == previous)
        #expect(LibraryLines.preferences(afterEditing: "plank", to: "plank\n", previous: previous) == previous)
        #expect(LibraryLines.preferences(afterEditing: "plank\n", to: "plank\nair squats", previous: previous) == previous)
        #expect(LibraryLines.preferences(afterEditing: "plank\npushups", to: "pushups", previous: previous).isEmpty)
        #expect(LibraryLines.preferences(afterEditing: "plank\npushups", to: "pushups\npushups", previous: previous).isEmpty)
    }

    struct SeededRandom: RandomNumberGenerator {
        var state: UInt64 = 42
        mutating func next() -> UInt64 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return state
        }
    }

    @Test(arguments: [1, 3, 5])
    func selectedExercisesAreUniqueAndRerollChangesOnlyOne(count: Int) throws {
        let library = LibraryParser.parse(SeedLibrary.text)
        var random = SeededRandom()
        for _ in 0..<30 {
            let original = try #require(SnackGenerator.generate(count: count, library: library, using: &random))
            #expect(Set(original).count == count)
            let replacement = try #require(SnackGenerator.reroll(at: 0, current: original, library: library, using: &random))
            #expect(replacement[0] != original[0])
            #expect(replacement.dropFirst() == original.dropFirst())
            #expect(Set(replacement).count == count)
        }
    }

    @Test func unicodeEquivalentsAreDuplicates() {
        #expect(LibraryParser.parse("café\ncafe\u{301}\nCAFÉ") == ["café"])
    }

    @Test func parsesAndDeduplicatesWithoutReordering() {
        #expect(LibraryParser.parse(" pushups \r\n\nDead Hang\npushups\nDEAD HANG\rplank\n")
                == ["pushups", "Dead Hang", "plank"])
    }

    @Test func unavailableSizesAndExhaustedRerolls() {
        var random = SystemRandomNumberGenerator()
        #expect(SnackGenerator.generate(count: 3, library: ["a", "b"], using: &random) == nil)
        #expect(SnackGenerator.reroll(at: 0, current: ["a"], library: ["a"], using: &random) == nil)
    }
}
