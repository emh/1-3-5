import Foundation

struct ExercisePreferences: Codable, Equatable, Sendable {
    var isMuted = false
    var isBoosted = false

    var weight: Int { isMuted ? 0 : isBoosted ? 2 : 1 }
    var isDefault: Bool { !isMuted && !isBoosted }
}

enum LibraryLines {
    struct Line {
        let range: NSRange
        let nameRange: NSRange
        let name: String
        var key: String { LibraryParser.key(for: name) }
    }

    static func lines(in text: String) -> [Line] {
        let source = text as NSString
        var result: [Line] = []
        var offset = 0
        while offset < source.length {
            var end = 0
            var contentEnd = 0
            source.getLineStart(nil, end: &end, contentsEnd: &contentEnd, for: NSRange(location: offset, length: 0))
            let range = NSRange(location: offset, length: contentEnd - offset)
            let content = source.substring(with: range) as NSString
            let name = (content as String).trimmingCharacters(in: .whitespaces)
            let localNameRange = content.range(of: name)
            let nameRange = NSRange(location: offset + (name.isEmpty ? 0 : localNameRange.location), length: (name as NSString).length)
            result.append(Line(range: range, nameRange: nameRange, name: name))
            offset = end
        }
        return result
    }

    static func selectedKeys(in text: String, range: NSRange) -> Set<String> {
        let length = (text as NSString).length
        guard range.location >= 0, range.location < length, range.length > 0 else { return [] }
        let start = range.location
        let end = start + min(range.length, length - start)
        let touched = lines(in: text).filter {
            !$0.name.isEmpty && start < NSMaxRange($0.nameRange) && end > $0.nameRange.location
        }
        // Never act on a partial exercise, including a partially highlighted boundary line.
        guard touched.allSatisfy({ start <= $0.nameRange.location && end >= NSMaxRange($0.nameRange) }) else { return [] }
        return Set(touched.map(\.key))
    }

    /// Keep preferences attached to names when lines move, and to the edited line when it is renamed.
    static func preferences(afterEditing oldText: String, to newText: String,
                            previous: [String: ExercisePreferences]) -> [String: ExercisePreferences] {
        let newLines = lines(in: newText)
        let newKeys = Set(newLines.map(\.key))
        var result = previous.filter { newKeys.contains($0.key) && !$0.value.isDefault }
        guard oldText != newText else { return result }
        let before = Array(oldText.utf16)
        let after = Array(newText.utf16)
        var prefix = 0
        while prefix < min(before.count, after.count), before[prefix] == after[prefix] { prefix += 1 }
        var suffix = 0
        while suffix < min(before.count, after.count) - prefix,
              before[before.count - suffix - 1] == after[after.count - suffix - 1] { suffix += 1 }
        let oldEnd = before.count - suffix
        let newEnd = after.count - suffix
        let oldLines = lines(in: oldText)
        guard let oldLine = oldLines.first(where: { prefix >= $0.range.location && oldEnd <= NSMaxRange($0.range) }),
              let nextLine = newLines.first(where: { prefix >= $0.range.location && newEnd <= NSMaxRange($0.range) }),
              !nextLine.key.isEmpty, !newKeys.contains(oldLine.key),
              !oldLines.contains(where: { $0.key == nextLine.key }),
              let preference = previous[oldLine.key]
        else { return result }
        result[nextLine.key] = preference
        return result
    }
}
