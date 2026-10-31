// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Ember",
    platforms: [.macOS(.v13)],
    targets: [
        // Pure logic with no AppKit or CoreGraphics, so it is unit-testable.
        .target(name: "EmberCore"),
        // The menu-bar app: talks to the window server and the status bar.
        .executableTarget(name: "Ember", dependencies: ["EmberCore"]),
        .testTarget(name: "EmberCoreTests", dependencies: ["EmberCore"]),
    ]
)
