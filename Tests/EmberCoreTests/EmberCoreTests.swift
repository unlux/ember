import Foundation
import Testing
@testable import EmberCore

@Suite struct GammaTableTests {
    @Test func nightTintKeepsRedAndRemovesGreenAndBlue() {
        let linear = GammaTable.linear(count: 256)
        let red = linear.tinted(by: .night)
        #expect(red.red == linear.red)
        #expect(red.green.allSatisfy { $0 == 0 })
        #expect(red.blue.allSatisfy { $0 == 0 })
        #expect(red.count == 256)
    }

    @Test func tintStartsFromTheDisplaysOwnCurve() throws {
        // A calibrated display's curve is not a straight line.
        let curve: [Float] = (0..<64).map { pow(Float($0) / 63, 2.2) }
        let calibrated = try #require(GammaTable(red: curve, green: curve, blue: curve))
        #expect(calibrated.tinted(by: .night).red == curve)
    }

    @Test func tintedValuesStayInRange() throws {
        let table = try #require(GammaTable(red: [-0.5, 0.5, 1.5], green: [0, 1, 2], blue: [0, 1, 1]))
        let tinted = table.tinted(by: Tint(red: 1, green: 0.5, blue: 1))
        #expect(tinted.red == [0, 0.5, 1])
        #expect(tinted.green == [0, 0.5, 1])
    }

    @Test func mismatchedChannelLengthsAreRejected() {
        #expect(GammaTable(red: [0, 1], green: [0], blue: [0, 1]) == nil)
        #expect(GammaTable(red: [], green: [], blue: []) == nil)
    }

    @Test func tablesWithinToleranceMatch() throws {
        let a = GammaTable.linear(count: 8)
        let b = try #require(GammaTable(red: a.red.map { $0 + 0.0005 }, green: a.green, blue: a.blue))
        #expect(a.matches(b))
    }

    @Test(arguments: ["red", "green", "blue"])
    func aChangeInAnyChannelIsAMismatch(channel: String) throws {
        let a = GammaTable.linear(count: 8)
        func bumped(_ c: [Float], _ name: String) -> [Float] {
            name == channel ? c.enumerated().map { $0.offset == 7 ? $0.element - 0.01 : $0.element } : c
        }
        let b = try #require(GammaTable(red: bumped(a.red, "red"), green: bumped(a.green, "green"), blue: bumped(a.blue, "blue")))
        #expect(!a.matches(b))
    }

    @Test func differentLengthsNeverMatch() {
        #expect(!GammaTable.linear(count: 8).matches(GammaTable.linear(count: 9)))
    }

    @Test func turningRedOnIsDetectedAsADifferentTable() {
        let linear = GammaTable.linear(count: 256)
        #expect(!linear.matches(linear.tinted(by: .night)))
    }
}

@Suite struct TintTests {
    @Test func multipliersAreClamped() {
        let tint = Tint(red: 2, green: -1, blue: .nan)
        #expect(tint == Tint(red: 1, green: 0, blue: 0))
    }

    @Test func nightIsPureRed() {
        #expect(Tint.night == Tint(red: 1, green: 0, blue: 0))
    }
}

@Suite struct ClickActionTests {
    @Test(arguments: [
        (false, false, ClickAction.toggle),
        (true, false, ClickAction.showMenu),
        (false, true, ClickAction.showMenu),
        (true, true, ClickAction.showMenu),
    ])
    func clicks(isRightClick: Bool, isControlHeld: Bool, expected: ClickAction) {
        #expect(ClickAction(isRightClick: isRightClick, isControlHeld: isControlHeld) == expected)
    }
}
