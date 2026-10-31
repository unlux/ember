extension Tint {
    /// No change: every channel at full strength.
    public static let neutral = Tint(red: 1, green: 1, blue: 1)

    /// Colour steps from normal to pure red, as (amount, green, blue). Red
    /// stays at 1 throughout. The middle steps are Dimit's calibrated warmth
    /// anchors (4000K, 2700K, 1900K and 1000K; MIT, see
    /// THIRD_PARTY_NOTICES.md), spaced evenly so each fifth of the slider
    /// moves one step: normal, warm white, amber, orange, deep orange, red.
    private static let rednessSteps: [(amount: Double, green: Double, blue: Double)] = [
        (0.0, 1.000, 1.000),
        (0.2, 0.850, 0.700),
        (0.4, 0.750, 0.500),
        (0.6, 0.585, 0.250),
        (0.8, 0.450, 0.080),
        (1.0, 0.000, 0.000),
    ]

    /// The tint for a redness from 0 (normal colours) to 1 (pure red).
    /// Linear between steps, so green and blue only ever fall as redness
    /// rises. Out-of-range and NaN values are clamped.
    public static func redness(_ amount: Double) -> Tint {
        let a = amount.isNaN ? 0 : min(max(amount, 0), 1)
        let steps = rednessSteps
        var upper = 1
        while upper < steps.count - 1 && steps[upper].amount < a { upper += 1 }
        let lo = steps[upper - 1]
        let hi = steps[upper]
        let t = (a - lo.amount) / (hi.amount - lo.amount)
        return Tint(
            red: 1,
            green: Float(lo.green + (hi.green - lo.green) * t),
            blue: Float(lo.blue + (hi.blue - lo.blue) * t)
        )
    }

    /// Straight-line blend: 0 gives `self`, 1 gives `other`.
    public func blended(with other: Tint, by fraction: Double) -> Tint {
        let f = Float(min(max(fraction, 0), 1))
        return Tint(
            red: red + (other.red - red) * f,
            green: green + (other.green - green) * f,
            blue: blue + (other.blue - blue) * f
        )
    }
}

/// Timing curve for fades.
public enum Easing {
    /// Slow start, slow end (smoothstep). Maps 0 to 0 and 1 to 1.
    public static func easeInOut(_ progress: Double) -> Double {
        let p = min(max(progress, 0), 1)
        return p * p * (3 - 2 * p)
    }
}
