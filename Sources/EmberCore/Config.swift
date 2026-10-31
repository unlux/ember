import Foundation

/// Everything you might want to change. Edit, then run scripts/install.sh.
public enum Config {
    /// Red from 8 PM to 7 AM, off during meetings. Times are the Mac's local
    /// time. Sprint review is listed first so the menu names it on Thursdays,
    /// when it overlaps the standup.
    public static let schedule = Schedule(
        red: TimeWindow(from: ClockTime(20, 0), to: ClockTime(7, 0)),
        exclusions: [
            Exclusion("Sprint review", on: [.thursday], from: ClockTime(21, 0), to: ClockTime(22, 30)),
            Exclusion("Standup", on: Weekday.workdays, from: ClockTime(21, 0), to: ClockTime(22, 0)),
        ]
    )

    /// Redness on first launch, from 0 (normal colours) to 1 (pure red).
    /// After that the menu's slider remembers your choice.
    public static let defaultRedness = 1.0

    /// How long red takes to fade in or out, in seconds. 0 switches instantly.
    public static let fadeDuration: TimeInterval = 0.6
}
