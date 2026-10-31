import AppKit
import CoreGraphics

/// Tells Ember when displays change or the Mac wakes, so red can be put back.
@MainActor
final class DisplayEvents {
    /// The CoreGraphics callback is a plain C function with no context, so it
    /// reaches the live instance through this. Only one instance ever exists.
    fileprivate static weak var current: DisplayEvents?

    private let onDisplaysChanged: () -> Void
    private let onWake: () -> Void
    private var observers: [NSObjectProtocol] = []
    private var pendingDisplayChange: DispatchWorkItem?
    private var pendingWake: DispatchWorkItem?

    init(onDisplaysChanged: @escaping () -> Void, onWake: @escaping () -> Void) {
        self.onDisplaysChanged = onDisplaysChanged
        self.onWake = onWake
        Self.current = self
        CGDisplayRegisterReconfigurationCallback(displayReconfigured, nil)

        let center = NSWorkspace.shared.notificationCenter
        let names: [Notification.Name] = [
            NSWorkspace.didWakeNotification,
            NSWorkspace.screensDidWakeNotification,
            NSWorkspace.sessionDidBecomeActiveNotification,
        ]
        for name in names {
            let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.woke() }
            }
            observers.append(token)
        }
    }

    /// One plug or unplug fires the callback several times, once per display
    /// and phase. Wait for it to settle, then react once.
    fileprivate func displaysChanged() {
        pendingDisplayChange?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.onDisplaysChanged() }
        pendingDisplayChange = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    /// The window server may reset colour tables during wake; give it a
    /// second to finish first.
    private func woke() {
        pendingWake?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.onWake() }
        pendingWake = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: work)
    }
}

private func displayReconfigured(
    _ display: CGDirectDisplayID,
    _ flags: CGDisplayChangeSummaryFlags,
    _ userInfo: UnsafeMutableRawPointer?
) {
    // The "begin" call arrives before anything has changed; wait for the end.
    guard !flags.contains(.beginConfigurationFlag) else { return }
    DispatchQueue.main.async {
        MainActor.assumeIsolated { DisplayEvents.current?.displaysChanged() }
    }
}
