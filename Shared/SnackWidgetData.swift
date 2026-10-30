import Foundation

struct SnackSchedule: Codable, Equatable, Sendable {
    var dailyTarget = 30
    var startMinute = 420
    var endMinute = 1140

    var isValid: Bool {
        (1...300).contains(dailyTarget)
            && (0..<1440).contains(startMinute) && (0..<1440).contains(endMinute) && startMinute != endMinute
    }

    /// Pace and completed snacks share the same local calendar day, including overnight schedules.
    func expectedCount(at date: Date, calendar: Calendar) -> Double {
        let day = calendar.dateInterval(of: .day, for: date)!
        let start = calendar.date(bySettingHour: startMinute / 60, minute: startMinute % 60, second: 0, of: day.start)!
        let end = calendar.date(bySettingHour: endMinute / 60, minute: endMinute % 60, second: 0, of: day.start)!
        let windows = startMinute < endMinute
            ? [DateInterval(start: start, end: max(start, end))]
            : [DateInterval(start: day.start, end: end), DateInterval(start: start, end: day.end)]
        let duration = windows.reduce(0) { $0 + $1.duration }
        guard duration > 0 else { return date >= end ? Double(dailyTarget) : 0 }
        let elapsed = windows.reduce(0) { $0 + min($1.duration, max(0, date.timeIntervalSince($1.start))) }
        return Double(dailyTarget) * elapsed / duration
    }
}

struct SnackWidgetSnapshot: Codable, Equatable, Sendable {
    var completions: [Date] = []
    var schedule = SnackSchedule()

    func state(at date: Date, calendar: Calendar = .current) -> SnackWidgetState {
        let count = completions.filter { $0 <= date && calendar.isDate($0, inSameDayAs: date) }.count
        return SnackWidgetState(count: count, target: schedule.dailyTarget,
                                expectedCount: schedule.expectedCount(at: date, calendar: calendar))
    }
}

struct SnackWidgetState {
    let count: Int
    let target: Int
    let expectedCount: Double

    var completedFraction: Double { min(1, Double(count) / Double(max(1, target))) }
    var expectedFraction: Double { min(1, max(0, expectedCount / Double(max(1, target)))) }
    // Match the displayed precision so a tiny difference never reads as "0 behind".
    var paceDifference: Double { ((Double(count) - expectedCount) * 10).rounded() / 10 }
}

enum SnackWidgetStorage {
    static let group = "group.local.ExerciseSnacks"
    static let kind = "SnackProgress"
    static var url: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)?.appending(path: "widget.json")
    }
    static func read() -> SnackWidgetSnapshot? {
        guard let url, let bytes = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(SnackWidgetSnapshot.self, from: bytes), snapshot.schedule.isValid else { return nil }
        return snapshot
    }
    static func write(_ snapshot: SnackWidgetSnapshot) throws {
        guard let url else { throw CocoaError(.fileNoSuchFile) }
        try JSONEncoder().encode(snapshot).write(to: url, options: .atomic)
    }
}
