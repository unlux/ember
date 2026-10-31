import AppKit
import EmberCore
import ServiceManagement

/// The menu-bar icon and its menu. Left click toggles red; right click or
/// Control-click opens the menu.
@MainActor
final class StatusItemController: NSObject {
    private let controller: EmberController
    private let configProblem: String?
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private let redItem = NSMenuItem(title: "Red Screen", action: #selector(toggleRed), keyEquivalent: "")
    private let sliderItem = NSMenuItem()
    private lazy var slider = RednessSlider { [weak self] value in self?.controller.setRedness(value) }
    private let scheduleItem = NSMenuItem(
        title: "Follow Schedule", action: #selector(toggleSchedule), keyEquivalent: "")
    private let summaryItem = NSMenuItem()
    private let nextItem = NSMenuItem()
    private let problemItem = NSMenuItem()
    private let loginItem = NSMenuItem(title: "Open at Login", action: #selector(toggleLogin), keyEquivalent: "")

    init(controller: EmberController, configProblem: String?) {
        self.controller = controller
        self.configProblem = configProblem
        super.init()

        sliderItem.view = slider
        for info in [summaryItem, nextItem, problemItem] {
            info.isEnabled = false
            info.indentationLevel = 1
        }
        if let configProblem {
            // Shown so a broken config.json can't fail silently.
            problemItem.title = "config.json ignored: \(configProblem)"
        }
        problemItem.isHidden = configProblem == nil
        let quitItem = NSMenuItem(title: "Quit Ember", action: #selector(quit), keyEquivalent: "q")
        for menuItem in [redItem, scheduleItem, loginItem, quitItem] { menuItem.target = self }
        menu.items = [
            redItem, sliderItem, .separator(),
            scheduleItem, summaryItem, nextItem, problemItem, .separator(),
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
        let wantsMenu = event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true
        if wantsMenu {
            showMenu()
        } else {
            controller.toggle()
        }
    }

    private func showMenu() {
        redItem.state = controller.isRed ? .on : .off
        slider.value = controller.redness

        let schedule = controller.config.schedule
        scheduleItem.state = controller.followsSchedule ? .on : .off
        summaryItem.title = "Red \(Self.format(schedule.red.start)) – \(Self.format(schedule.red.end))"
        let next = controller.nextScheduledChange().map(Self.describe)
        nextItem.title = next ?? ""
        nextItem.isHidden = next == nil

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

    // MARK: - Menu wording

    /// "Next: off at 9:00 PM for Standup", "Next: red on tomorrow at 8:00 PM".
    private static func describe(_ change: Schedule.Change) -> String {
        let calendar = Calendar.current
        let time = change.date.formatted(date: .omitted, time: .shortened)
        let when: String
        if calendar.isDateInToday(change.date) {
            when = "at \(time)"
        } else if calendar.isDateInTomorrow(change.date) {
            when = "tomorrow at \(time)"
        } else {
            when = "\(change.date.formatted(.dateTime.weekday(.wide))) at \(time)"
        }
        if change.state.isRed { return "Next: red on \(when)" }
        if let exclusion = change.state.exclusion { return "Next: off \(when) for \(exclusion)" }
        return "Next: off \(when)"
    }

    /// A clock time in the user's 12- or 24-hour style.
    private static func format(_ time: ClockTime) -> String {
        let calendar = Calendar.current
        var parts = calendar.dateComponents([.year, .month, .day], from: Date())
        parts.hour = time.hour
        parts.minute = time.minute
        guard let date = calendar.date(from: parts) else { return time.description }
        return date.formatted(date: .omitted, time: .shortened)
    }
}
