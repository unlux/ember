import ColorSync
import CoreGraphics
import EmberCore

/// An active display, with the CoreGraphics calls Ember makes on it.
struct Display {
    let id: CGDirectDisplayID
    /// Stable across unplug and replug, unlike `id`.
    let uuid: String

    static func active() -> [Display] {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &ids, &count) == .success else { return [] }
        return ids.prefix(Int(count)).map { Display(id: $0, uuid: uuid(for: $0)) }
    }

    private static func uuid(for id: CGDirectDisplayID) -> String {
        guard let uuid = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue() else {
            return "display-\(id)"
        }
        return CFUUIDCreateString(nil, uuid) as String
    }

    /// The display's current colour table, or nil if it has none to read
    /// (some virtual displays report a capacity of 0).
    func readTable() -> GammaTable? {
        let capacity = CGDisplayGammaTableCapacity(id)
        guard capacity > 0 else { return nil }
        var red = [CGGammaValue](repeating: 0, count: Int(capacity))
        var green = red
        var blue = red
        var sampleCount: UInt32 = 0
        guard CGGetDisplayTransferByTable(id, capacity, &red, &green, &blue, &sampleCount) == .success,
              sampleCount > 0
        else { return nil }
        let n = Int(sampleCount)
        return GammaTable(red: Array(red.prefix(n)), green: Array(green.prefix(n)), blue: Array(blue.prefix(n)))
    }

    /// Public CoreGraphics API. macOS undoes this when Ember's process exits,
    /// including on a crash or `kill -9`.
    func write(_ table: GammaTable) -> CGError {
        CGSetDisplayTransferByTable(id, UInt32(table.count), table.red, table.green, table.blue)
    }
}
