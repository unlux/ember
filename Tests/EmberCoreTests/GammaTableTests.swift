import Foundation
import Testing

@testable import EmberCore

@Suite struct GammaTableTests {
    @Test func fullRednessKeepsRedAndRemovesGreenAndBlue() {
        let linear = GammaTable.linear(count: 256)
        let red = linear.tinted(by: .redness(1))
        #expect(red.red == linear.red)
        #expect(red.green.allSatisfy { $0 == 0 })
        #expect(red.blue.allSatisfy { $0 == 0 })
        #expect(red.count == 256)
    }

    @Test func tintStartsFromTheDisplaysOwnCurve() throws {
        // A calibrated display's curve is not a straight line.
        let curve: [Float] = (0..<64).map { pow(Float($0) / 63, 2.2) }
        let calibrated = try #require(GammaTable(red: curve, green: curve, blue: curve))
        #expect(calibrated.tinted(by: .redness(1)).red == curve)
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
        let b = try #require(
            GammaTable(red: bumped(a.red, "red"), green: bumped(a.green, "green"), blue: bumped(a.blue, "blue")))
        #expect(!a.matches(b))
    }

    @Test func differentLengthsNeverMatch() {
        #expect(!GammaTable.linear(count: 8).matches(GammaTable.linear(count: 9)))
    }
}
