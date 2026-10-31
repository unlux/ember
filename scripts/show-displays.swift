// Prints each display's colour table, so you can tell whether Ember's tint is
// applied without seeing the screen. Screenshots can't show it: the table is
// applied after capture. Run on the Mac: swift scripts/show-displays.swift
import CoreGraphics
import Foundation

var count: UInt32 = 0
CGGetActiveDisplayList(0, nil, &count)
var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
CGGetActiveDisplayList(count, &ids, &count)
for id in ids.prefix(Int(count)) {
    let capacity = CGDisplayGammaTableCapacity(id)
    var r = [CGGammaValue](repeating: 0, count: Int(capacity))
    var g = r
    var b = r
    var n: UInt32 = 0
    guard CGGetDisplayTransferByTable(id, capacity, &r, &g, &b, &n) == .success, n > 0 else {
        print("display \(id): no readable table")
        continue
    }
    // The top entry is what white becomes. Normal: 1.00 1.00 1.00.
    let top = Int(n) - 1
    let state = g[top] > 0.99 && b[top] > 0.99 ? "normal" : (g[top] < 0.01 && b[top] < 0.01 ? "full red" : "tinted")
    let builtIn = CGDisplayIsBuiltin(id) != 0 ? " (built-in)" : ""
    print(
        String(
            format: "display %u%@: white -> red %.2f green %.2f blue %.2f, %@", id, builtIn, r[top], g[top], b[top],
            state))
}
