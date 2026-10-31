import AppKit
import EmberCore

/// Ember's state: whether red is on, how red, and the schedule.
///
/// Schedule rule: Ember acts only when the schedule's answer changes (red
/// starting, an exclusion starting or ending, red ending). A click in
/// between overrides the schedule until its next change.
@MainActor
final class EmberController {
    private enum Key {
        static let red = "redEnabled"
        static let redness = "redness"
        static let followsSchedule = "followsSchedule"
    }

    let config: Config
    private let defaults: UserDefaults
    private let gamma: GammaController
    private let fader: Fader

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

    init(config: Config, defaults: UserDefaults, gamma: GammaController) {
        self.config = config
        self.defaults = defaults
        self.gamma = gamma
        self.fader = Fader(gamma: gamma)
        defaults.register(defaults: [Key.redness: 1.0, Key.followsSchedule: true])
        redness = defaults.double(forKey: Key.redness)
        followsSchedule = defaults.bool(forKey: Key.followsSchedule)
    }

    func start() {
        if followsSchedule {
            checkSchedule()
        } else if defaults.bool(forKey: Key.red) {
            setRed(true)
        }
        // Every 10 seconds, so an exclusion starts within 10 s of its time.
        // Each check is a few integer comparisons.
        scheduleTimer = repeatingTimer(every: 10, tolerance: 2) { $0.checkSchedule() }

        let center = NotificationCenter.default
        for name in [Notification.Name.NSSystemClockDidChange, .NSSystemTimeZoneDidChange] {
            clockObservers.append(
                center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
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
        fader.fade(to: on ? .redness(redness) : nil, duration: animated ? config.fadeSeconds : 0)
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

    /// The next time the schedule switches red on or off, for the menu.
    func nextScheduledChange() -> Schedule.Change? {
        guard followsSchedule else { return nil }
        return config.schedule.nextChange(after: Date(), calendar: .current)
    }

    private func checkSchedule() {
        guard followsSchedule else { return }
        let scheduled = config.schedule.state(at: Date(), calendar: .current).isRed
        guard scheduled != lastScheduledRed else { return }
        lastScheduledRed = scheduled
        if scheduled != isRed { setRed(scheduled) }
    }

    /// While red is on, check every few seconds that every display still
    /// shows it (after sleep, a monitor reconnect, a display glitch) and put
    /// it back if not. Reads only; writes only on a mismatch.
    private func startWatchdog() {
        stopWatchdog()
        watchdog = repeatingTimer(every: 3, tolerance: 1) { $0.gamma.enforce() }
    }

    private func stopWatchdog() {
        watchdog?.invalidate()
        watchdog = nil
    }

    /// A main-thread timer that also runs while the menu is open.
    private func repeatingTimer(
        every interval: TimeInterval,
        tolerance: TimeInterval,
        _ action: @escaping @MainActor (EmberController) -> Void
    ) -> Timer {
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                if let self { action(self) }
            }
        }
        timer.tolerance = tolerance
        RunLoop.main.add(timer, forMode: .common)
        return timer
    }
}
