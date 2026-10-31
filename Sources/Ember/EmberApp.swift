import AppKit

@main
enum EmberApp {
    @MainActor
    static func main() {
        if CommandLine.arguments.contains("--check-config") {
            exit(ConfigFile.check())
        }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        // Menu bar only: no Dock icon, no app switcher entry. Info.plist's
        // LSUIElement says the same for launches through Finder.
        app.setActivationPolicy(.accessory)
        // `delegate` is weak on NSApplication; keep ours alive for the run.
        withExtendedLifetime(delegate) {
            app.run()
        }
    }
}
