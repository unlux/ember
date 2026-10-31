import Foundation

/// A time of day, to the minute.
public struct ClockTime: Equatable, Sendable {
    public let hour: Int
    public let minute: Int

    public init(_ hour: Int, _ minute: Int = 0) {
        precondition((0..<24).contains(hour) && (0..<60).contains(minute), "invalid time \(hour):\(minute)")
        self.hour = hour
        self.minute = minute
    }

    /// Parses 24-hour "HH:MM", such as "07:00" or "21:30".
    public init?(parsing text: String) {
        let parts = text.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2, parts[1].count == 2,
              let hour = Int(parts[0]), let minute = Int(parts[1]),
              (0..<24).contains(hour), (0..<60).contains(minute)
        else { return nil }
        self.init(hour, minute)
    }

    var minuteOfDay: Int { hour * 60 + minute }
}

/// Calendar weekday numbers, as `Calendar.component(.weekday, ...)` returns
/// them for the Gregorian calendar.
public enum Weekday: Int, Sendable, CaseIterable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

    public static let workdays: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]

    /// "mon", "tue" … "sun", as written in config.json.
    public var shortName: String {
        ["sun", "mon", "tue", "wed", "thu", "fri", "sat"][rawValue - 1]
    }

    public init?(shortName: String) {
        guard let match = Weekday.allCases.first(where: { $0.shortName == shortName.lowercased() }) else { return nil }
        self = match
    }

    var previous: Weekday { Weekday(rawValue: rawValue == 1 ? 7 : rawValue - 1)! }
}

/// From `start` up to (not including) `end`. If `end` is earlier than
/// `start`, the window runs past midnight.
public struct TimeWindow: Equatable, Sendable {
    public let start: ClockTime
    public let end: ClockTime

    public init(from start: ClockTime, to end: ClockTime) {
        self.start = start
        self.end = end
    }

    var crossesMidnight: Bool { end.minuteOfDay < start.minuteOfDay }

    func contains(minuteOfDay m: Int) -> Bool {
        let s = start.minuteOfDay
        let e = end.minuteOfDay
        if s == e { return false }
        return crossesMidnight ? (m >= s || m < e) : (m >= s && m < e)
    }
}

/// A recurring time when red must stay off, such as a meeting.
public struct Exclusion: Equatable, Sendable {
    public let name: String
    public let days: Set<Weekday>
    public let window: TimeWindow

    public init(_ name: String, on days: Set<Weekday>, from start: ClockTime, to end: ClockTime) {
        self.name = name
        self.days = days
        self.window = TimeWindow(from: start, to: end)
    }

    /// `days` are the days the window starts on. A window past midnight
    /// also covers the early hours of the following day.
    func contains(weekday: Weekday, minuteOfDay m: Int) -> Bool {
        guard window.contains(minuteOfDay: m) else { return false }
        guard window.crossesMidnight else { return days.contains(weekday) }
        return m >= window.start.minuteOfDay ? days.contains(weekday) : days.contains(weekday.previous)
    }
}

/// When red should be on: every day during `red`, except during any
/// exclusion. Exclusions are checked in order, so list the one whose name
/// should win first.
public struct Schedule: Equatable, Sendable {
    public let red: TimeWindow
    public let exclusions: [Exclusion]

    public init(red: TimeWindow, exclusions: [Exclusion] = []) {
        self.red = red
        self.exclusions = exclusions
    }

    public struct State: Equatable, Sendable {
        public let isRed: Bool
        /// The exclusion keeping red off, if one is.
        public let exclusion: String?
    }

    public func state(at date: Date, calendar: Calendar) -> State {
        let parts = calendar.dateComponents([.weekday, .hour, .minute], from: date)
        let minute = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        let weekday = Weekday(rawValue: parts.weekday ?? 1) ?? .sunday
        if let exclusion = exclusions.first(where: { $0.contains(weekday: weekday, minuteOfDay: minute) }) {
            return State(isRed: false, exclusion: exclusion.name)
        }
        return State(isRed: red.contains(minuteOfDay: minute), exclusion: nil)
    }

    public struct Change: Equatable, Sendable {
        public let date: Date
        public let state: State
    }

    /// The next minute at which red switches on or off, looking up to eight
    /// days ahead. Nil if the schedule never changes.
    public func nextChange(after date: Date, calendar: Calendar) -> Change? {
        let now = state(at: date, calendar: calendar)
        guard var minute = calendar.dateInterval(of: .minute, for: date)?.end else { return nil }
        for _ in 0..<(8 * 24 * 60) {
            let candidate = state(at: minute, calendar: calendar)
            if candidate.isRed != now.isRed { return Change(date: minute, state: candidate) }
            minute = minute.addingTimeInterval(60)
        }
        return nil
    }
}
