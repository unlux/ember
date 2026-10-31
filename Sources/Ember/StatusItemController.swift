import AppKit
import EmberCore
import ServiceManagement

/// The menu-bar icon. Left click toggles red; right click or Control-click
/// opens the menu.
@MainActor
final class StatusItemController: NSObject {
    private let controller: EmberController
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private let redItem = NSMenuItem(title: "Red Screen", action: #selector(toggleRed), keyEquivalent: "")
    private let sliderItem = NSMenuItem()
    private lazy var slider = RednessSlider { [weak self] value in self?.controller.setRedness(value) }
    private let scheduleItem = NSMenuItem(title: "Follow Schedule", action: #selector(toggleSchedule), keyEquivalent: "")
    private let summaryItem = NSMenuItem()
    private let nextItem = NSMenuItem()
    private let loginItem = NSMenuItem(title: "Open at Login", action: #selector(toggleLogin), keyEquivalent: "")

    init(controller: EmberController) {
        self.controller = controller
        super.init()

        sliderItem.view = slider
        for info in [summaryItem, nextItem] {
            info.isEnabled = false
            info.indentationLevel = 1
        }
        let quitItem = NSMenuItem(title: "Quit Ember", action: #selector(quit), keyEquivalent: "q")
        for menuItem in [redItem, scheduleItem, loginItem, quitItem] { menuItem.target = self }
        menu.items = [
            redItem, sliderItem, .separator(),
            scheduleItem, summaryItem, nextItem, .separator(),
            loginItem, quitItem,
        ]

        if let button = item.button {
            button.target = self
            button.action = #selector(clicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "Ember: click to turn the screen red. Right-click for options."
        }
        refresh()
    }

    /// Updates the icon. Called by the controller after every change.
    func refresh() {
        let isRed = controller.isRed
        let image = NSImage(
            systemSymbolName: isRed ? "moon.fill" : "moon",
            accessibilityDescription: isRed ? "Ember, red on" : "Ember, red off"
        )
        image?.isTemplate = true
        item.button?.image = image
        redItem.state = isRed ? .on : .off
    }

    @objc private func clicked() {
        let event = NSApp.currentEvent
        let action = ClickAction(
            isRightClick: event?.type == .rightMouseUp,
            isControlHeld: event?.modifierFlags.contains(.control) ?? false
        )
        switch action {
        case .toggle: controller.toggle()
        case .showMenu: showMenu()
        }
    }

    private func showMenu() {
        redItem.state = controller.isRed ? .on : .off
        slider.value = controller.redness

        scheduleItem.state = controller.followsSchedule ? .on : .off
        summaryItem.title = controller.scheduleSummary
        if let next = controller.nextChangeDescription {
            nextItem.title = next
            nextItem.isHidden = false
        } else {
            nextItem.isHidden = true
        }

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

    @objc private func toggleRed() { controller.toggle() }

    @objc private func toggleSchedule() { controller.setFollowsSchedule(!controller.followsSchedule) }

    @objc private func toggleLogin() {
        switch LoginItem.status {
        case .enabled: LoginItem.setEnabled(false)
        case .requiresApproval: SMAppService.openSystemSettingsLoginItems()
        default: LoginItem.setEnabled(true)
        }
    }

    @objc private func quit() { NSApp.terminate(nil) }
}
