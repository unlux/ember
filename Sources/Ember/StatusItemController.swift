import AppKit
import EmberCore
import ServiceManagement

/// The menu-bar icon. Left click toggles red; right click or Control-click
/// opens the menu.
@MainActor
final class StatusItemController: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private let redItem = NSMenuItem(title: "Red Screen", action: #selector(toggleRed), keyEquivalent: "")
    private let loginItem = NSMenuItem(title: "Open at Login", action: #selector(toggleLogin), keyEquivalent: "")
    private let onToggle: () -> Void

    var isRed = false {
        didSet { updateIcon() }
    }

    init(onToggle: @escaping () -> Void) {
        self.onToggle = onToggle
        super.init()

        redItem.target = self
        loginItem.target = self
        let quitItem = NSMenuItem(title: "Quit Ember", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.items = [redItem, loginItem, .separator(), quitItem]

        if let button = item.button {
            button.target = self
            button.action = #selector(clicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "Ember: click to turn the screen red. Right-click for options."
        }
        updateIcon()
    }

    @objc private func clicked() {
        let event = NSApp.currentEvent
        let action = ClickAction(
            isRightClick: event?.type == .rightMouseUp,
            isControlHeld: event?.modifierFlags.contains(.control) ?? false
        )
        switch action {
        case .toggle: onToggle()
        case .showMenu: showMenu()
        }
    }

    private func showMenu() {
        redItem.state = isRed ? .on : .off
        switch LoginItem.status {
        case .enabled:
            loginItem.title = "Open at Login"
            loginItem.state = .on
        case .requiresApproval:
            loginItem.title = "Open at Login (allow in System Settings…)"
            loginItem.state = .mixed
        default:
            loginItem.title = "Open at Login"
            loginItem.state = .off
        }
        loginItem.isEnabled = LoginItem.isInstalled
        loginItem.toolTip = LoginItem.isInstalled ? nil : "Only available when Ember is in /Applications."

        // Attaching the menu only for this click keeps left click free for
        // toggling. performClick blocks until the menu closes.
        item.menu = menu
        item.button?.performClick(nil)
        item.menu = nil
    }

    private func updateIcon() {
        let image = NSImage(
            systemSymbolName: isRed ? "moon.fill" : "moon",
            accessibilityDescription: isRed ? "Ember, red on" : "Ember, red off"
        )
        image?.isTemplate = true
        item.button?.image = image
    }

    @objc private func toggleRed() { onToggle() }

    @objc private func toggleLogin() {
        switch LoginItem.status {
        case .enabled: LoginItem.setEnabled(false)
        case .requiresApproval: SMAppService.openSystemSettingsLoginItems()
        default: LoginItem.setEnabled(true)
        }
    }

    @objc private func quit() { NSApp.terminate(nil) }
}
