import CoreGraphics
import EmberCore
import os

/// Owns every colour-table change Ember makes.
///
/// Rule: a display's baseline (its normal table) is only ever read straight
/// after `CGDisplayRestoreColorSyncSettings()`. That way a tinted table can
/// never be mistaken for the normal one and baked in.
@MainActor
final class GammaController {
    private let log = Logger(subsystem: "dev.unlux.ember", category: "gamma")

    /// What is on screen now; nil when the displays are untouched.
    private(set) var currentTint: Tint?
    /// Normal tables, keyed by display UUID. Empty while untouched.
    private var baselines: [String: GammaTable] = [:]
    /// Displays with no readable table. Remembered so `enforce()` doesn't
    /// restart from scratch, and flash every display, on each watchdog tick.
    private var unsupported: Set<String> = []

    /// Puts `tint` on every display. Called once per frame during a fade.
    func show(_ tint: Tint) {
        if currentTint == nil {
            captureBaselines()
        }
        currentTint = tint
        for display in Display.active() {
            guard let baseline = baselines[display.uuid] else { continue }
            write(baseline.tinted(by: tint), to: display)
        }
    }

    /// Hands every display back to its ColorSync profile.
    func restore() {
        CGDisplayRestoreColorSyncSettings()
        currentTint = nil
        baselines.removeAll()
        unsupported.removeAll()
    }

    /// Re-reads all baselines and re-applies the current tint. Used when
    /// displays are added, removed or reconfigured.
    func reapplyFromScratch() {
        guard let tint = currentTint else { return }
        captureBaselines()
        show(tint)
        log.info("re-applied to \(self.baselines.count, privacy: .public) display(s) after a display change")
    }

    /// Re-applies the tint to any display whose table no longer matches,
    /// such as after sleep. Cheap enough to run every few seconds.
    func enforce() {
        guard let tint = currentTint else { return }
        let displays = Display.active()
        if displays.contains(where: { baselines[$0.uuid] == nil && !unsupported.contains($0.uuid) }) {
            reapplyFromScratch()
            return
        }
        for display in displays {
            guard let baseline = baselines[display.uuid] else { continue }
            let expected = baseline.tinted(by: tint)
            if let current = display.readTable(), current.matches(expected) { continue }
            log.notice("display \(display.id, privacy: .public) lost its tint; re-applying")
            write(expected, to: display)
        }
    }

    private func captureBaselines() {
        CGDisplayRestoreColorSyncSettings()
        baselines.removeAll()
        unsupported.removeAll()
        for display in Display.active() {
            if let table = display.readTable() {
                baselines[display.uuid] = table
            } else {
                unsupported.insert(display.uuid)
                log.error("display \(display.id, privacy: .public) has no readable colour table; leaving it alone")
            }
        }
    }

    private func write(_ table: GammaTable, to display: Display) {
        let result = display.write(table)
        if result != .success {
            log.error("CGSetDisplayTransferByTable failed (\(result.rawValue, privacy: .public)) on display \(display.id, privacy: .public)")
        }
    }
}
