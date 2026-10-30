import Foundation
import Testing
@testable import ExerciseSnacks

struct WidgetTests {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }
    private func date(_ hour: Int, _ minute: Int = 0, day: Int = 28) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    @Test func countsExercisesInCompletedSetsWithoutResettingPace() {
        let sets = (0..<4).map { hour in
            Snack(id: UUID(), completedAt: date(8 + hour), exercises: ["a", "b", "c", "d", "e"])
        }
        var data = StoredData(libraryText: "", snacks: sets)
        var state = data.widgetSnapshot.state(at: date(11, 30), calendar: calendar)
        #expect(state.count == 20)
        #expect(state.completedFraction == 20.0 / 30.0)
        #expect(state.expectedCount == 11.25)
        data.snacks.append(Snack(id: UUID(), completedAt: date(12), exercises: ["a", "b", "c"]))
        data.snacks.append(Snack(id: UUID(), completedAt: date(13), exercises: ["a"]))
        data.snacks.append(Snack(id: UUID(), completedAt: date(18, day: 27), exercises: ["a", "b", "c"]))
        state = data.widgetSnapshot.state(at: date(13), calendar: calendar)
        #expect(state.count == 24)
        #expect(state.expectedCount == 15)
        #expect(state.paceDifference == 9)
    }

    @Test func expectedSnacksAccumulateAcrossWindowAndHoldAtTarget() {
        let snapshot = SnackWidgetSnapshot()
        for (hour, minute, expected) in [(0, 0, 0.0), (6, 59, 0), (7, 0, 0), (7, 30, 1.25),
                                        (10, 0, 7.5), (13, 0, 15), (19, 0, 30), (23, 59, 30)] {
            let state = snapshot.state(at: date(hour, minute), calendar: calendar)
            #expect(state.expectedCount == expected)
            #expect(state.expectedFraction == expected / 30)
        }
        let custom = SnackWidgetSnapshot(schedule: SnackSchedule(dailyTarget: 12, startMinute: 480, endMinute: 1200))
        #expect(custom.state(at: date(14), calendar: calendar).expectedCount == 6)
    }

    @Test func paceDistinguishesBehindAlignedAndAhead() {
        for (count, difference) in [(12, -3.0), (15, 0), (18, 3)] {
            let state = SnackWidgetSnapshot(completions: Array(repeating: date(8), count: count))
                .state(at: date(13), calendar: calendar)
            #expect(state.paceDifference == difference)
            #expect(state.expectedFraction == 0.5)
        }
        let almostAligned = SnackWidgetSnapshot(completions: Array(repeating: date(8), count: 15))
            .state(at: date(13).addingTimeInterval(1), calendar: calendar)
        #expect(almostAligned.paceDifference == 0)
    }

    @Test func midnightResetsBothCountAndExpected() {
        let snapshot = SnackWidgetSnapshot(completions: [date(8), date(18)])
        #expect(snapshot.state(at: date(23, 59), calendar: calendar).count == 2)
        let tomorrow = snapshot.state(at: date(0, day: 29), calendar: calendar)
        #expect(tomorrow.count == 0)
        #expect(tomorrow.expectedCount == 0)
    }

    @Test func overnightPaceUsesSameCalendarDayAsCompletedSnacks() {
        let schedule = SnackSchedule(dailyTarget: 8, startMinute: 22 * 60, endMinute: 6 * 60)
        let snapshot = SnackWidgetSnapshot(completions: [date(23)], schedule: schedule)
        for (hour, minute, expected) in [(0, 0, 0.0), (0, 30, 0.5), (6, 0, 6), (12, 0, 6), (22, 0, 6), (23, 0, 7)] {
            let state = snapshot.state(at: date(hour, minute, day: 29), calendar: calendar)
            #expect(state.count == 0)
            #expect(state.expectedCount == expected)
        }
    }

    @Test func goalDoesNotWrapAndFutureRecordsAreExcluded() {
        for count in [0, 15, 30, 38, 60, 150] {
            let snapshot = SnackWidgetSnapshot(completions: Array(repeating: date(8), count: count) + [date(10)])
            let state = snapshot.state(at: date(9), calendar: calendar)
            #expect(state.count == count)
            #expect(state.completedFraction == min(1, Double(count) / 30))
        }
    }

    @Test func daylightSavingUsesActualWindowDuration() {
        var local = calendar
        local.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let schedule = SnackSchedule(dailyTarget: 8, startMinute: 0, endMinute: 4 * 60)
        // Fall-back day: midnight to 4am spans five elapsed hours; 2am is three hours in.
        let fall = local.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 2))!
        #expect(abs(schedule.expectedCount(at: fall, calendar: local) - 4.8) < 0.0001)
        // Spring-forward day: midnight to 4am spans three elapsed hours; 3am is two hours in.
        let spring = local.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 3))!
        #expect(abs(schedule.expectedCount(at: spring, calendar: local) - 16.0 / 3) < 0.0001)
    }

    @Test func settingsRoundTripAndLegacyDefaults() throws {
        var data = StoredData.seed
        data.snackSchedule = SnackSchedule(dailyTarget: 12, startMinute: 480, endMinute: 1200)
        #expect(try JSONCodec.decoder().decode(StoredData.self, from: JSONCodec.encoder().encode(data)) == data)
        #expect(try JSONCodec.importData(JSONCodec.encoder().encode(ExportPayload(data: data))) == data)
        let legacy = Data(#"{"version":1,"library":[],"snacks":[]}"#.utf8)
        #expect(try JSONCodec.importData(legacy).snackSchedule == SnackSchedule())
        let oldSchedule = Data(#"{"version":1,"library":[],"snacks":[],"snackSchedule":{"dailyTarget":12,"intervalMinutes":30,"startMinute":480,"endMinute":1200}}"#.utf8)
        #expect(try JSONCodec.importData(oldSchedule).snackSchedule == data.snackSchedule)
        let oldStorage = Data(#"{"version":1,"libraryText":"","snacks":[],"snackSchedule":{"dailyTarget":12,"intervalMinutes":30,"startMinute":480,"endMinute":1200}}"#.utf8)
        #expect(try JSONCodec.decoder().decode(StoredData.self, from: oldStorage).snackSchedule == data.snackSchedule)
        let encoded = try JSONCodec.encoder().encode(data)
        #expect(!String(decoding: encoded, as: UTF8.self).contains("intervalMinutes"))
        data.snackSchedule.dailyTarget = 0
        #expect(throws: (any Error).self) { try DataValidation.stored(data) }
        data.snackSchedule = SnackSchedule(startMinute: 420, endMinute: 420)
        #expect(throws: (any Error).self) { try DataValidation.stored(data) }
    }
}
