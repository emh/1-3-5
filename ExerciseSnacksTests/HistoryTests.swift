import Foundation
import Testing
@testable import ExerciseSnacks

struct HistoryTests {
    @Test func dayGroupingFollowsCalendarAcrossDSTAndTimeZones() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Vancouver"))
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 9, hour: 0, minute: 5)))
        let previous = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 0, minute: 5)))
        let snacks = [now, previous].map { Snack(id: UUID(), completedAt: $0, exercises: ["a"]) }
        let sections = HistoryGrouping.sections(for: snacks, now: now, calendar: calendar)
        #expect(sections.map(\.title) == ["TODAY", "YESTERDAY"])
        #expect(now.timeIntervalSince(previous) == 23 * 60 * 60)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        #expect(HistoryGrouping.sections(for: snacks, now: now, calendar: calendar).flatMap(\.snacks).count == 2)
    }
}
