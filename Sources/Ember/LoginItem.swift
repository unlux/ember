import Foundation
import ServiceManagement
import os

/// "Open at Login", through the same system list as System Settings >
/// General > Login Items.
@MainActor
enum LoginItem {
    private static let log = Logger(subsystem: "dev.unlux.ember", category: "login")
    private static let configuredKey = "loginItemConfigured"

    static var status: SMAppService.Status { SMAppService.mainApp.status }

    /// Login items point at the app's path, so only register the installed
    /// copy, never a build-folder one.
    static var isInstalled: Bool {
        Bundle.main.bundleURL.path.hasPrefix("/Applications/")
    }

    /// Turns Open at Login on the first time the installed app runs. After
    /// that the user's choice in the menu wins.
    static func enableOnFirstLaunch(_ defaults: UserDefaults) {
        if isInstalled, !defaults.bool(forKey: configuredKey) {
            setEnabled(true)
            defaults.set(true, forKey: configuredKey)
        }
        log.notice("Open at Login status: \(describe(status), privacy: .public)")
    }

    private static func describe(_ status: SMAppService.Status) -> String {
        switch status {
        case .enabled: "enabled"
        case .requiresApproval: "needs approval in System Settings"
        case .notRegistered: "off"
        case .notFound: "not found"
        @unknown default: "unknown (\(status.rawValue))"
        }
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            log.error("Open at Login \(enabled ? "on" : "off", privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
