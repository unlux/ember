import Testing

@testable import EmberCore

@Suite struct TintTests {
    @Test func multipliersAreClamped() {
        #expect(Tint(red: 2, green: -1, blue: .nan) == Tint(red: 1, green: 0, blue: 0))
    }

    @Test func rednessZeroIsNormalAndOneIsPureRed() {
        #expect(Tint.redness(0) == .neutral)
        #expect(Tint.redness(1) == Tint(red: 1, green: 0, blue: 0))
    }

    @Test func rednessStepsLandExactly() {
        #expect(Tint.redness(0.4) == Tint(red: 1, green: 0.75, blue: 0.5))
        #expect(Tint.redness(0.8) == Tint(red: 1, green: 0.45, blue: 0.08))
    }

    @Test func moreRednessNeverAddsGreenOrBlue() {
        var previous = Tint.redness(0)
        for i in 1...200 {
            let tint = Tint.redness(Double(i) / 200)
            #expect(tint.red == 1)
            #expect(tint.green <= previous.green)
            #expect(tint.blue <= previous.blue)
            previous = tint
        }
    }

    @Test func rednessOutOfRangeIsClamped() {
        #expect(Tint.redness(-1) == .neutral)
        #expect(Tint.redness(7) == .redness(1))
        #expect(Tint.redness(.nan) == .neutral)
    }

    @Test func blendHitsBothEndsAndTheMiddle() {
        let red = Tint.redness(1)
        #expect(Tint.neutral.blended(with: red, by: 0) == .neutral)
        #expect(Tint.neutral.blended(with: red, by: 1) == red)
        #expect(Tint.neutral.blended(with: red, by: 0.5) == Tint(red: 1, green: 0.5, blue: 0.5))
    }

    @Test func easingStartsAndEndsInPlaceAndOnlyMovesForward() {
        #expect(Easing.easeInOut(0) == 0)
        #expect(Easing.easeInOut(1) == 1)
        #expect(Easing.easeInOut(0.5) == 0.5)
        var previous = 0.0
        for i in 1...100 {
            let value = Easing.easeInOut(Double(i) / 100)
            #expect(value >= previous)
            previous = value
        }
    }
}
