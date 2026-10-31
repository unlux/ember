import Foundation
import Testing
@testable import EmberCore

/// Shared by the schedule and config tests.
enum Fixtures {
    /// Fixed zone so the tests don't depend on where they run.
    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Kolkata")!
        return c
    }()

    /// A date in the week of Sunday 1 Nov to Saturday 7 Nov 2026, whose day
    /// numbers match `Weekday`'s raw values.
    static func date(_ weekday: Weekday, _ hour: Int, _ minute: Int = 0) -> Date {
        let result = calendar.date(from: DateComponents(year: 2026, month: 11, day: weekday.rawValue, hour: hour, minute: minute))!
        precondition(calendar.component(.weekday, from: result) == weekday.rawValue, "test calendar is off")
        return result
    }

    /// The repo's config.example.json.
    static let exampleConfig = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appending(path: "config.example.json")

    /// Red 20:00–07:00, off for a Thursday review and a weekday standup.
    /// Matches config.example.json.
    static let meetings = Schedule(
        red: TimeWindow(from: ClockTime(20), to: ClockTime(7)),
        exclusions: [
            Exclusion("Sprint review", on: [.thursday], from: ClockTime(21), to: ClockTime(22, 30)),
            Exclusion("Standup", on: Weekday.workdays, from: ClockTime(21), to: ClockTime(22)),
        ]
    )
}

@Suite struct ScheduleTests {
    let calendar = Fixtures.calendar
    let schedule = Fixtures.meetings
    func date(_ weekday: Weekday, _ hour: Int, _ minute: Int = 0) -> Date { Fixtures.date(weekday, hour, minute) }

    @Test(arguments: [
        (Weekday.monday, 19, 59, false, nil as String?),
        (.monday, 20, 0, true, nil),
        (.monday, 20, 59, true, nil),
        (.monday, 21, 0, false, "Standup"),
        (.monday, 21, 59, false, "Standup"),
        (.monday, 22, 0, true, nil),
        (.tuesday, 3, 0, true, nil),
        (.tuesday, 6, 59, true, nil),
        (.tuesday, 7, 0, false, nil),
        (.tuesday, 12, 0, false, nil),
        (.thursday, 21, 0, false, "Sprint review"),
        (.thursday, 22, 15, false, "Sprint review"),
        (.thursday, 22, 30, true, nil),
        (.friday, 21, 30, false, "Standup"),
        (.saturday, 21, 30, true, nil),
        (.sunday, 21, 30, true, nil),
    ])
    func stateAt(weekday: Weekday, hour: Int, minute: Int, isRed: Bool, exclusion: String?) {
        let state = schedule.state(at: date(weekday, hour, minute), calendar: calendar)
        #expect(state == Schedule.State(isRed: isRed, exclusion: exclusion))
    }

    @Test func nextChangeIsTheStandupWhenRedIsOnBeforeIt() throws {
        let change = try #require(schedule.nextChange(after: date(.monday, 20, 30), calendar: calendar))
        #expect(change.date == date(.monday, 21))
        #expect(change.state == Schedule.State(isRed: false, exclusion: "Standup"))
    }

    @Test func nextChangeAfterSprintReviewIsRedAtHalfPastTen() throws {
        let change = try #require(schedule.nextChange(after: date(.thursday, 21, 5), calendar: calendar))
        #expect(change.date == date(.thursday, 22, 30))
        #expect(change.state.isRed)
    }

    @Test func nextChangeDuringTheDayIsEightPM() throws {
        let change = try #require(schedule.nextChange(after: date(.monday, 12, 0), calendar: calendar))
        #expect(change.date == date(.monday, 20))
    }

    @Test func nextChangeIsOnAMinuteBoundaryEvenFromMidMinute() throws {
        let start = date(.monday, 20, 59).addingTimeInterval(30)
        let change = try #require(schedule.nextChange(after: start, calendar: calendar))
        #expect(change.date == date(.monday, 21))
    }

    @Test func scheduleThatNeverChangesHasNoNextChange() {
        let never = Schedule(red: TimeWindow(from: ClockTime(9), to: ClockTime(9)))
        #expect(never.nextChange(after: date(.monday, 12), calendar: calendar) == nil)
    }

    @Test func exclusionPastMidnightCoversTheNextMorning() {
        let late = Schedule(
            red: TimeWindow(from: ClockTime(20), to: ClockTime(7)),
            exclusions: [Exclusion("Late call", on: [.friday], from: ClockTime(23, 30), to: ClockTime(0, 30))]
        )
        #expect(late.state(at: date(.friday, 23, 45), calendar: calendar).exclusion == "Late call")
        #expect(late.state(at: date(.saturday, 0, 15), calendar: calendar).exclusion == "Late call")
        #expect(late.state(at: date(.saturday, 0, 30), calendar: calendar).isRed)
        #expect(late.state(at: date(.thursday, 23, 45), calendar: calendar).isRed)
    }
}
