import AppKit
import EmberCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let redKey = "redEnabled"

    private let defaults = UserDefaults.standard
    private let gamma = GammaController()
    private var statusItem: StatusItemController?
    private var displayEvents: DisplayEvents?
    private var watchdog: Timer?
    private var signalSources: [any DispatchSourceSignal] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        // A second copy would add a second icon. Leave with exit(), not
        // terminate(): terminate() would run applicationWillTerminate and
        // turn off the first copy's red.
        if isAnotherCopyRunning() { exit(0) }

        handleTerminationSignals()
        statusItem = StatusItemController(onToggle: { [weak self] in self?.toggle() })
        displayEvents = DisplayEvents(
            onDisplaysChanged: { [weak self] in self?.gamma.reapplyFromScratch() },
            onWake: { [weak self] in self?.gamma.enforce() }
        )
        LoginItem.enableOnFirstLaunch(defaults)

        // Come back the way the user left it.
        if defaults.bool(forKey: Self.redKey) { setRed(true) }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // macOS would undo the tables on exit anyway; restoring here makes
        // the screen return to normal before the process is gone.
        gamma.turnOff()
    }

    private func toggle() {
        setRed(!gamma.isOn)
    }

    private func setRed(_ on: Bool) {
        if on {
            gamma.turnOn(.night)
            startWatchdog()
        } else {
            stopWatchdog()
            gamma.turnOff()
        }
        defaults.set(on, forKey: Self.redKey)
        statusItem?.isRed = on
    }

    /// While red is on, check every few seconds that no one has reset the
    /// colour tables (Night Shift, another colour app, a display glitch) and
    /// put red back if they have. Reads only; writes only on a mismatch.
    private func startWatchdog() {
        stopWatchdog()
        let timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.gamma.enforce() }
        }
        timer.tolerance = 1
        watchdog = timer
    }

    private func stopWatchdog() {
        watchdog?.invalidate()
        watchdog = nil
    }

    /// `kill`, Ctrl-C and logout send these. Route them through a normal quit.
    private func handleTerminationSignals() {
        for sig in [SIGTERM, SIGINT, SIGHUP] {
            signal(sig, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            source.setEventHandler {
                MainActor.assumeIsolated { NSApp.terminate(nil) }
            }
            source.resume()
            signalSources.append(source)
        }
    }

    private func isAnotherCopyRunning() -> Bool {
        guard let bundleID = Bundle.main.bundleIdentifier else { return false }
        return NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .contains { $0 != NSRunningApplication.current }
    }
}
