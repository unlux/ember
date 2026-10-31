import CoreGraphics
import EmberCore
import os

/// Owns every colour-table change Ember makes.
///
/// Rule: a display's baseline (its normal table) is only ever read straight
/// after `CGDisplayRestoreColorSyncSettings()`. That way a red table can
/// never be mistaken for the normal one and baked in.
@MainActor
final class GammaController {
    private let log = Logger(subsystem: "dev.unlux.ember", category: "gamma")

    /// nil while off.
    private var tint: Tint?
    /// Normal tables, keyed by display UUID.
    private var baselines: [String: GammaTable] = [:]
    /// Displays with no readable table. Remembered so `enforce()` doesn't
    /// restart from scratch, and flash every display, on each watchdog tick.
    private var unsupported: Set<String> = []

    var isOn: Bool { tint != nil }

    func turnOn(_ tint: Tint) {
        self.tint = tint
        reapplyFromScratch()
    }

    func turnOff() {
        tint = nil
        // Resets every display to its ColorSync profile in one call.
        CGDisplayRestoreColorSyncSettings()
    }

    /// Restores every display, re-reads all baselines, and applies the tint.
    /// Used when switching on and whenever displays are added, removed or
    /// reconfigured.
    func reapplyFromScratch() {
        guard let tint else { return }
        CGDisplayRestoreColorSyncSettings()
        baselines.removeAll()
        unsupported.removeAll()
        for display in Display.active() {
            guard let baseline = display.readTable() else {
                unsupported.insert(display.uuid)
                log.error("display \(display.id, privacy: .public) has no readable colour table; leaving it alone")
                continue
            }
            baselines[display.uuid] = baseline
            write(baseline.tinted(by: tint), to: display)
        }
        log.info("red applied to \(self.baselines.count, privacy: .public) display(s)")
    }

    /// Re-applies the tint to any display whose table no longer matches,
    /// such as after sleep or when another app resets colours. Cheap enough
    /// to run every few seconds.
    func enforce() {
        guard let tint else { return }
        let displays = Display.active()
        if displays.contains(where: { baselines[$0.uuid] == nil && !unsupported.contains($0.uuid) }) {
            reapplyFromScratch()
            return
        }
        for display in displays {
            guard let baseline = baselines[display.uuid] else { continue }
            let expected = baseline.tinted(by: tint)
            if let current = display.readTable(), current.matches(expected) { continue }
            log.notice("display \(display.id, privacy: .public) lost the red table; re-applying")
            write(expected, to: display)
        }
    }

    private func write(_ table: GammaTable, to display: Display) {
        let result = display.write(table)
        if result != .success {
            log.error("CGSetDisplayTransferByTable failed (\(result.rawValue, privacy: .public)) on display \(display.id, privacy: .public)")
        }
    }
}
