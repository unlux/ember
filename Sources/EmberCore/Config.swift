import Foundation

/// A person's settings, read from `~/.config/ember/config.json`. Every key is
/// optional; a missing file means `Config.standard`. See config.example.json.
///
///     {
///       "red": { "from": "20:00", "to": "07:00" },
///       "exclusions": [
///         { "name": "Standup", "days": ["mon", "tue", "wed", "thu", "fri"],
///           "from": "21:00", "to": "22:00" }
///       ],
///       "fadeSeconds": 0.6
///     }
public struct Config: Equatable, Sendable {
    /// When the schedule turns red on, and the times it keeps red off.
    public var schedule: Schedule
    /// How long red takes to fade in or out. 0 switches instantly.
    public var fadeSeconds: Double

    public init(schedule: Schedule, fadeSeconds: Double) {
        self.schedule = schedule
        self.fadeSeconds = fadeSeconds
    }

    /// Red from 8 PM to 7 AM, no exclusions, 0.6 s fades.
    public static let standard = Config(
        schedule: Schedule(red: TimeWindow(from: ClockTime(20), to: ClockTime(7))),
        fadeSeconds: 0.6
    )

    /// Strict on purpose: unknown keys and malformed values are errors that
    /// name the exact spot, so a typo can't be silently ignored.
    public static func parse(_ data: Data) throws -> Config {
        let json: Any
        do {
            json = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw ConfigError("not valid JSON (\(error.localizedDescription))")
        }
        guard let root = json as? [String: Any] else { throw ConfigError("the top level must be an object { … }") }
        try requireOnly(["red", "exclusions", "fadeSeconds"], in: root, at: "")

        var red = standard.schedule.red
        if let value = root["red"] {
            red = try window(value, at: "red")
        }

        var exclusions: [Exclusion] = []
        if let value = root["exclusions"] {
            guard let list = value as? [Any] else { throw ConfigError("exclusions: must be a list [ … ]") }
            exclusions = try list.enumerated().map { try exclusion($1, at: "exclusions[\($0)]") }
        }

        var fadeSeconds = standard.fadeSeconds
        if let value = root["fadeSeconds"] {
            // `is Bool` would also match the numbers 0 and 1, so ask
            // CoreFoundation whether it's a real JSON true/false.
            guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(),
                (0...10).contains(number.doubleValue)
            else { throw ConfigError("fadeSeconds: must be a number from 0 to 10") }
            fadeSeconds = number.doubleValue
        }

        return Config(schedule: Schedule(red: red, exclusions: exclusions), fadeSeconds: fadeSeconds)
    }

    // MARK: - Pieces

    private static func window(_ value: Any, at path: String) throws -> TimeWindow {
        guard let object = value as? [String: Any] else {
            throw ConfigError("\(path): must be an object like { \"from\": \"20:00\", \"to\": \"07:00\" }")
        }
        try requireOnly(["from", "to"], in: object, at: path)
        return TimeWindow(
            from: try time(object["from"], at: "\(path).from"),
            to: try time(object["to"], at: "\(path).to")
        )
    }

    private static func exclusion(_ value: Any, at path: String) throws -> Exclusion {
        guard let object = value as? [String: Any] else { throw ConfigError("\(path): must be an object { … }") }
        try requireOnly(["name", "days", "from", "to"], in: object, at: path)
        guard let name = object["name"] as? String, !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw ConfigError("\(path).name: needs a name, such as \"Standup\"")
        }
        guard let dayNames = object["days"] as? [String], !dayNames.isEmpty else {
            throw ConfigError("\(path).days: needs a list of days, such as [\"mon\", \"wed\"]")
        }
        let days = try dayNames.map { name in
            guard let day = Weekday(shortName: name) else {
                throw ConfigError("\(path).days: \"\(name)\" is not one of mon, tue, wed, thu, fri, sat, sun")
            }
            return day
        }
        return Exclusion(
            name,
            on: Set(days),
            from: try time(object["from"], at: "\(path).from"),
            to: try time(object["to"], at: "\(path).to")
        )
    }

    private static func time(_ value: Any?, at path: String) throws -> ClockTime {
        guard let text = value as? String else {
            throw ConfigError("\(path): missing; use 24-hour time like \"21:30\"")
        }
        guard let time = ClockTime(parsing: text) else {
            throw ConfigError("\(path): \"\(text)\" is not a 24-hour time like \"21:30\"")
        }
        return time
    }

    private static func requireOnly(_ allowed: Set<String>, in object: [String: Any], at path: String) throws {
        if let unknown = object.keys.sorted().first(where: { !allowed.contains($0) }) {
            let place = path.isEmpty ? "" : "\(path): "
            throw ConfigError(
                "\(place)unknown key \"\(unknown)\"; allowed: \(allowed.sorted().joined(separator: ", "))")
        }
    }
}

/// What's wrong with config.json, phrased for the person or agent fixing it.
public struct ConfigError: Error, Equatable, CustomStringConvertible {
    public let description: String
    init(_ description: String) { self.description = description }
}

extension Config {
    /// One line per rule, for `Ember --check-config`.
    public var summary: String {
        func days(_ set: Set<Weekday>) -> String {
            Weekday.allCases.filter(set.contains).map(\.shortName).joined(separator: ",")
        }
        func span(_ window: TimeWindow) -> String { "\(window.start)–\(window.end)" }
        var lines = ["red \(span(schedule.red)) every day"]
        for exclusion in schedule.exclusions {
            lines.append("off \(span(exclusion.window)) on \(days(exclusion.days)) for \(exclusion.name)")
        }
        lines.append("fade \(fadeSeconds) s")
        return lines.joined(separator: "\n")
    }
}

extension ClockTime: CustomStringConvertible {
    /// "07:00", "21:30".
    public var description: String {
        String(format: "%02d:%02d", hour, minute)
    }
}
