import Foundation
import Testing
@testable import EmberCore

@Suite struct ConfigTests {
    func parse(_ json: String) throws -> Config {
        try Config.parse(Data(json.utf8))
    }

    /// The error message, or nil if the JSON parsed.
    func problem(_ json: String) -> String? {
        do {
            _ = try parse(json)
            return nil
        } catch {
            return String(describing: error)
        }
    }

    @Test func exampleFileParsesToTheMeetingsSchedule() throws {
        let config = try Config.parse(Data(contentsOf: Fixtures.exampleConfig))
        #expect(config.schedule == Fixtures.meetings)
        #expect(config.fadeSeconds == 0.6)
    }

    @Test func emptyObjectIsTheStandardConfig() throws {
        #expect(try parse("{}") == .standard)
    }

    @Test func eachKeyIsOptional() throws {
        let config = try parse(#"{ "fadeSeconds": 0 }"#)
        #expect(config.schedule == Config.standard.schedule)
        #expect(config.fadeSeconds == 0)
    }

    @Test func wholeNumberFadeIsANumberNotABool() throws {
        #expect(try parse(#"{ "fadeSeconds": 1 }"#).fadeSeconds == 1)
        #expect(problem(#"{ "fadeSeconds": true }"#) != nil)
    }

    @Test(arguments: [
        (#"not json"#, "not valid JSON"),
        (#"[]"#, "the top level must be an object"),
        (#"{ "exclusion": [] }"#, #"unknown key "exclusion""#),
        (#"{ "red": { "from": "8pm", "to": "07:00" } }"#, #"red.from: "8pm" is not a 24-hour time"#),
        (#"{ "red": { "from": "20:00" } }"#, "red.to: missing"),
        (#"{ "red": { "from": "24:00", "to": "07:00" } }"#, "red.from"),
        (#"{ "exclusions": [ { "name": "X", "days": ["thurs"], "from": "21:00", "to": "22:00" } ] }"#, #"exclusions[0].days: "thurs" is not one of"#),
        (#"{ "exclusions": [ { "name": "", "days": ["mon"], "from": "21:00", "to": "22:00" } ] }"#, "exclusions[0].name"),
        (#"{ "exclusions": [ { "name": "X", "days": [], "from": "21:00", "to": "22:00" } ] }"#, "exclusions[0].days"),
        (#"{ "exclusions": [ { "name": "X", "days": ["mon"], "from": "21:00", "to": "22:00", "until": "x" } ] }"#, #"exclusions[0]: unknown key "until""#),
        (#"{ "fadeSeconds": 60 }"#, "fadeSeconds: must be a number from 0 to 10"),
    ])
    func badConfigNamesTheProblem(json: String, expected: String) {
        let message = problem(json)
        #expect(message?.contains(expected) == true, "got: \(message ?? "no error")")
    }

    @Test func daysAreCaseInsensitive() throws {
        let config = try parse(#"{ "exclusions": [ { "name": "X", "days": ["Mon", "FRI"], "from": "21:00", "to": "22:00" } ] }"#)
        #expect(config.schedule.exclusions.first?.days == [.monday, .friday])
    }

    @Test func summaryListsEveryRule() throws {
        let summary = try Config.parse(Data(contentsOf: Fixtures.exampleConfig)).summary
        #expect(summary == """
            red 20:00–07:00 every day
            off 21:00–22:30 on thu for Sprint review
            off 21:00–22:00 on mon,tue,wed,thu,fri for Standup
            fade 0.6 s
            """)
    }
}
