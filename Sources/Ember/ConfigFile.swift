import EmberCore
import Foundation
import os

/// Reads `~/.config/ember/config.json`. Ember reads it once, at launch.
enum ConfigFile {
    static let url = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: ".config/ember/config.json")

    struct Loaded {
        let config: Config
        /// Why the file was ignored, for the menu. Nil when it loaded or
        /// doesn't exist.
        let problem: String?
    }

    /// Never fails: a missing file means the standard config, and a broken
    /// one means the standard config plus a problem to show.
    static func load() -> Loaded {
        let log = Logger(subsystem: "dev.unlux.ember", category: "config")
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch CocoaError.fileReadNoSuchFile {
            log.notice("no config file; using the standard schedule")
            return Loaded(config: .standard, problem: nil)
        } catch {
            log.error("can't read \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return Loaded(config: .standard, problem: "can't read the file")
        }
        do {
            let config = try Config.parse(data)
            log.notice("loaded \(url.path, privacy: .public)")
            return Loaded(config: config, problem: nil)
        } catch {
            log.error("ignoring \(url.path, privacy: .public): \(String(describing: error), privacy: .public)")
            return Loaded(config: .standard, problem: String(describing: error))
        }
    }

    /// `Ember --check-config`: validate the file without starting the app.
    /// Prints the rules or the error; exit status 0 means valid.
    static func check() -> Int32 {
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("No \(url.path); Ember uses the standard config:\n\(Config.standard.summary)")
            return 0
        }
        let loaded = load()
        if let problem = loaded.problem {
            print("\(url.path): \(problem)")
            return 1
        }
        print("\(url.path) is valid:\n\(loaded.config.summary)")
        return 0
    }
}
