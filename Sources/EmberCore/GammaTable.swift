/// One display's colour lookup table. For each channel, entry `i` is the
/// output level (0...1) for input level `i / (count - 1)`. This is the shape
/// `CGGetDisplayTransferByTable` returns and `CGSetDisplayTransferByTable`
/// takes.
public struct GammaTable: Equatable, Sendable {
    public let red: [Float]
    public let green: [Float]
    public let blue: [Float]

    /// Returns nil unless all three channels are non-empty and the same length.
    public init?(red: [Float], green: [Float], blue: [Float]) {
        guard !red.isEmpty, red.count == green.count, red.count == blue.count else { return nil }
        self.red = red
        self.green = green
        self.blue = blue
    }

    public var count: Int { red.count }

    /// The table with each channel scaled by the tint's multiplier. Starting
    /// from the display's own table keeps any calibration in the red channel.
    public func tinted(by tint: Tint) -> GammaTable {
        func scale(_ channel: [Float], _ multiplier: Float) -> [Float] {
            channel.map { min(max($0 * multiplier, 0), 1) }
        }
        // Lengths are unchanged, so the failable init cannot fail here.
        return GammaTable(
            red: scale(red, tint.red),
            green: scale(green, tint.green),
            blue: scale(blue, tint.blue)
        )!
    }

    /// True when both tables have the same length and every entry in every
    /// channel is within `tolerance`. Comparing all three channels matters:
    /// a reset that restores only green and blue would otherwise go unnoticed.
    public func matches(_ other: GammaTable, tolerance: Float = 0.001) -> Bool {
        guard count == other.count else { return false }
        func same(_ a: [Float], _ b: [Float]) -> Bool {
            zip(a, b).allSatisfy { abs($0 - $1) <= tolerance }
        }
        return same(red, other.red) && same(green, other.green) && same(blue, other.blue)
    }

    /// A straight-line table, which is what a Mac without a custom profile
    /// reports. Used by tests.
    static func linear(count: Int) -> GammaTable {
        let ramp = (0..<count).map { Float($0) / Float(max(count - 1, 1)) }
        return GammaTable(red: ramp, green: ramp, blue: ramp)!
    }
}

/// Per-channel multipliers applied to a display's colour table.
public struct Tint: Equatable, Sendable {
    public let red: Float
    public let green: Float
    public let blue: Float

    /// Multipliers are clamped to 0...1; NaN becomes 0.
    public init(red: Float, green: Float, blue: Float) {
        func clamp(_ value: Float) -> Float { value.isNaN ? 0 : min(max(value, 0), 1) }
        self.red = clamp(red)
        self.green = clamp(green)
        self.blue = clamp(blue)
    }

    /// Red at full strength, green and blue removed: white becomes pure red
    /// and the screen emits no blue or green light.
    public static let night = Tint(red: 1, green: 0, blue: 0)
}
