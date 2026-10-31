import AppKit
import EmberCore

/// Ember's state: whether red is on, how red, and the schedule.
///
/// Schedule rule: Ember acts only when the schedule's answer changes (8 PM,
/// a meeting starting or ending, 7 AM). A click in between overrides the
/// schedule until its next change.
@MainActor
final class EmberController {
    private enum Key {
        static let red = "redEnabled"
        static let redness = "redness"
        static let followsSchedule = "followsSchedule"
    }

    private let defaults: UserDefaults
    private let gamma: GammaController
    private let fader: Fader
    private let schedule = Config.schedule
    private var calendar: Calendar { .current }

    private(set) var isRed = false
    private(set) var redness: Double
    private(set) var followsSchedule: Bool
    /// The schedule's answer when last checked; nil forces the next check
    /// to act.
    private var lastScheduledRed: Bool?
    private var watchdog: Timer?
    private var scheduleTimer: Timer?
    private var clockObservers: [NSObjectProtocol] = []

    /// Called after any change, so the menu-bar icon can update.
    var onChange: (() -> Void)?

    init(defaults: UserDefaults, gamma: GammaController) {
        self.defaults = defaults
        self.gamma = gamma
        self.fader = Fader(gamma: gamma)
        defaults.register(defaults: [
            Key.redness: Config.defaultRedness,
            Key.followsSchedule: true,
        ])
        redness = defaults.double(forKey: Key.redness)
        followsSchedule = defaults.bool(forKey: Key.followsSchedule)
    }

    func start() {
        if followsSchedule {
            checkSchedule()
        } else if defaults.bool(forKey: Key.red) {
            setRed(true)
        }
        // Checks every 10 seconds, so a meeting gap starts within 10 s of
        // its time. Each check is a few integer comparisons.
        let timer = Timer(timeInterval: 10, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkSchedule() }
        }
        timer.tolerance = 2
        RunLoop.main.add(timer, forMode: .common)
        scheduleTimer = timer

        let center = NotificationCenter.default
        for name in [Notification.Name.NSSystemClockDidChange, .NSSystemTimeZoneDidChange] {
            clockObservers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.checkSchedule() }
            })
        }
    }

    /// Normal colours right away, for quitting.
    func shutdown() {
        fader.cancel()
        stopWatchdog()
        scheduleTimer?.invalidate()
        gamma.restore()
    }

    func toggle() {
        setRed(!isRed)
    }

    func setRed(_ on: Bool, animated: Bool = true) {
        isRed = on
        defaults.set(on, forKey: Key.red)
        fader.fade(to: on ? .redness(redness) : nil, duration: animated ? Config.fadeDuration : 0)
        if on { startWatchdog() } else { stopWatchdog() }
        onChange?()
    }

    /// From the slider. Applies live; moving it while red is off turns red on.
    func setRedness(_ value: Double) {
        redness = min(max(value, 0), 1)
        defaults.set(redness, forKey: Key.redness)
        if isRed {
            fader.cancel()
            gamma.show(.redness(redness))
            onChange?()
        } else {
            setRed(true, animated: false)
        }
    }

    func setFollowsSchedule(_ on: Bool) {
        followsSchedule = on
        defaults.set(on, forKey: Key.followsSchedule)
        lastScheduledRed = nil
        checkSchedule()
        onChange?()
    }

    /// After wake: the clock may have passed a scheduled change while asleep,
    /// and the window server may have reset the tables.
    func handleWake() {
        checkSchedule()
        gamma.enforce()
    }

    func checkSchedule() {
        guard followsSchedule else { return }
        let scheduled = schedule.state(at: Date(), calendar: calendar).isRed
        guard scheduled != lastScheduledRed else { return }
        lastScheduledRed = scheduled
        if scheduled != isRed { setRed(scheduled) }
    }

    // MARK: - Text for the menu

    var scheduleSummary: String {
        "Red \(format(schedule.red.start)) – \(format(schedule.red.end))"
    }

    var nextChangeDescription: String? {
        guard followsSchedule, let change = schedule.nextChange(after: Date(), calendar: calendar) else { return nil }
        let when = describe(change.date)
        if change.state.isRed { return "Next: red on \(when)" }
        if let meeting = change.state.exclusion { return "Next: off \(when) for \(meeting)" }
        return "Next: off \(when)"
    }

    private func format(_ time: ClockTime) -> String {
        var parts = calendar.dateComponents([.year, .month, .day], from: Date())
        parts.hour = time.hour
        parts.minute = time.minute
        guard let date = calendar.date(from: parts) else { return "\(time.hour):\(time.minute)" }
        return date.formatted(date: .omitted, time: .shortened)
    }

    private func describe(_ date: Date) -> String {
        let time = date.formatted(date: .omitted, time: .shortened)
        if calendar.isDateInToday(date) { return "at \(time)" }
        if calendar.isDateInTomorrow(date) { return "tomorrow at \(time)" }
        return "\(date.formatted(.dateTime.weekday(.wide))) at \(time)"
    }

    // MARK: - Watchdog

    /// While red is on, check every few seconds that every display still
    /// shows it (after sleep, a monitor reconnect, a display glitch) and put
    /// it back if not. Reads only; writes only on a mismatch.
    private func startWatchdog() {
        stopWatchdog()
        let timer = Timer(timeInterval: 3, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.gamma.enforce() }
        }
        timer.tolerance = 1
        RunLoop.main.add(timer, forMode: .common)
        watchdog = timer
    }

    private func stopWatchdog() {
        watchdog?.invalidate()
        watchdog = nil
    }
}
