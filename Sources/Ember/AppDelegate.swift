import AppKit
import EmberCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let gamma = GammaController()
    private var controller: EmberController?
    private var statusItem: StatusItemController?
    private var displayEvents: DisplayEvents?
    private var signalSources: [any DispatchSourceSignal] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        // A second copy would add a second icon. Leave with exit(), not
        // terminate(): terminate() would run applicationWillTerminate and
        // turn off the first copy's red.
        if isAnotherCopyRunning() { exit(0) }

        handleTerminationSignals()

        let controller = EmberController(defaults: .standard, gamma: gamma)
        let statusItem = StatusItemController(controller: controller)
        controller.onChange = { [weak statusItem] in statusItem?.refresh() }
        displayEvents = DisplayEvents(
            onDisplaysChanged: { [weak self] in self?.gamma.reapplyFromScratch() },
            onWake: { [weak controller] in controller?.handleWake() }
        )
        LoginItem.enableOnFirstLaunch(.standard)
        self.controller = controller
        self.statusItem = statusItem
        controller.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // macOS would undo the tables on exit anyway; restoring here makes
        // the screen return to normal before the process is gone.
        controller?.shutdown()
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
