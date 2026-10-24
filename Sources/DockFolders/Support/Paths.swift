import Foundation

/// Well-known locations used by DockFolders.
enum Paths {
    static var home: String { NSHomeDirectory() }

    static func expand(_ path: String) -> String {
        var p = (path as NSString).expandingTildeInPath
        if p.contains("$HOME") { p = p.replacingOccurrences(of: "$HOME", with: home) }
        return (p as NSString).standardizingPath
    }

    static func abbreviate(_ path: String) -> String {
        (path as NSString).abbreviatingWithTildeInPath
    }

    static var configDir: URL {
        let env = ProcessInfo.processInfo.environment
        let base = env["XDG_CONFIG_HOME"].map { URL(fileURLWithPath: $0) }
            ?? URL(fileURLWithPath: home).appendingPathComponent(".config")
        return base.appendingPathComponent("dockfolders", isDirectory: true)
    }

    static var configFile: URL { configDir.appendingPathComponent("config.json") }
    static var legacyConfigFile: URL { configDir.appendingPathComponent("config.sh") }
    static var stateFile: URL { configDir.appendingPathComponent("state.json") }
    static var imagesDir: URL { configDir.appendingPathComponent("images", isDirectory: true) }
    static var defaultBackupDir: String { "~/.config/dockfolders/backups" }
    static var defaultFoldersDir: String { "~/Applications/DockFolders" }

    @discardableResult
    static func ensureDir(_ url: URL) -> Bool {
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            return true
        } catch {
            return false
        }
    }
}
