import Foundation

/// Reads and writes the Dock's preference domain directly (what dockutil does under the hood).
enum DockManager {
    /// Overridable for tests: `DOCKFOLDERS_DOCK_DOMAIN=com.example.test`.
    static var domain: String {
        ProcessInfo.processInfo.environment["DOCKFOLDERS_DOCK_DOMAIN"] ?? "com.apple.dock"
    }
    static var isRealDock: Bool { domain == "com.apple.dock" }

    struct DockError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    typealias Tile = [String: Any]

    // MARK: Reading

    static func readTiles(_ key: String) -> [Tile] {
        (CFPreferencesCopyAppValue(key as CFString, domain as CFString) as? [Tile]) ?? []
    }

    static var persistentOthers: [Tile] { readTiles("persistent-others") }
    static var persistentApps: [Tile] { readTiles("persistent-apps") }

    static func path(of tile: Tile) -> String? {
        guard let data = tile["tile-data"] as? [String: Any],
              let file = data["file-data"] as? [String: Any],
              let urlString = file["_CFURLString"] as? String else { return nil }
        if let url = URL(string: urlString), url.isFileURL {
            return (url.path as NSString).standardizingPath
        }
        return (urlString as NSString).standardizingPath
    }

    static func label(of tile: Tile) -> String? {
        ((tile["tile-data"] as? [String: Any])?["file-label"] as? String)
    }

    static func isOurs(_ tile: Tile, root: String) -> Bool {
        guard let p = path(of: tile) else { return false }
        let r = (root as NSString).standardizingPath
        return p == r || p.hasPrefix(r + "/")
    }

    // MARK: Tiles

    static func guid() -> Int { Int(UInt32.random(in: 1...UInt32.max)) }

    static func folderTile(path: String, label: String, display: FolderDisplay) -> Tile {
        let url = URL(fileURLWithPath: path, isDirectory: true)
        return [
            "tile-type": "directory-tile",
            "GUID": guid(),
            "tile-data": [
                "file-data": ["_CFURLString": url.absoluteString, "_CFURLStringType": 15] as [String: Any],
                "file-label": label,
                "file-type": 2,
                "arrangement": display.arrangement.rawValue,
                "displayas": display.displayAs.rawValue,
                "showas": display.showAs.rawValue,
                "preferreditemsize": -1,
            ] as [String: Any],
        ]
    }

    static func appTile(_ app: InstalledApp) -> Tile {
        let url = URL(fileURLWithPath: app.path, isDirectory: true)
        var data: [String: Any] = [
            "file-data": ["_CFURLString": url.absoluteString, "_CFURLStringType": 15] as [String: Any],
            "file-label": app.displayName,
            "file-type": 41,
            "dock-extra": false,
        ]
        if let b = app.bundleID { data["bundle-identifier"] = b }
        return ["tile-type": "file-tile", "GUID": guid(), "tile-data": data]
    }

    static func spacerTile(small: Bool) -> Tile {
        ["tile-type": small ? "small-spacer-tile" : "spacer-tile", "GUID": guid(), "tile-data": [:] as [String: Any]]
    }

    // MARK: Writing

    static func write(_ tiles: [Tile], to key: String) {
        CFPreferencesSetAppValue(key as CFString, tiles as CFArray, domain as CFString)
    }

    static func synchronize() throws {
        if !CFPreferencesAppSynchronize(domain as CFString) {
            throw DockError(message: "Could not write Dock preferences (\(domain)).")
        }
    }

    static func restartDock() {
        guard isRealDock else { return }
        Shell.run("/usr/bin/killall", ["Dock"], timeout: 10)
    }

    /// Puts our folder tiles into the Dock, optionally replacing the app section with the favorites.
    static func apply(folders: [(path: String, label: String, display: FolderDisplay)],
                      favorites: [InstalledApp],
                      settings: AppSettings,
                      log: (String) -> Void = { _ in }) throws {
        let root = settings.foldersDirectoryExpanded

        // Right-hand section: our folders first, then whatever else the user had (Downloads…).
        var others = persistentOthers
        let before = others.count
        others.removeAll { isOurs($0, root: root) }
        var newOthers = folders.map { folderTile(path: $0.path, label: $0.label, display: $0.display) }
        if settings.keepOtherDockItems {
            newOthers.append(contentsOf: others)
            if !others.isEmpty { log("  · kept \(others.count) existing Dock item(s)") }
        }
        write(newOthers, to: "persistent-others")
        log("  ✓ \(folders.count) folder tile(s) (replaced \(before - others.count))")

        // Left-hand section.
        if settings.manageFavorites {
            var apps = favorites.map(appTile)
            if settings.useSpacer && !apps.isEmpty {
                apps.append(spacerTile(small: settings.smallSpacer))
            }
            write(apps, to: "persistent-apps")
            log("  ✓ \(favorites.count) favorite(s)\(settings.useSpacer && !apps.isEmpty ? " + spacer" : "")")
        } else {
            log("  · app section left untouched")
        }

        try synchronize()
        if settings.restartDock {
            restartDock()
            log(isRealDock ? "  ✓ Dock restarted" : "  · test domain — Dock not restarted")
        }
    }

    /// Removes only the tiles that point into our folders directory.
    static func removeOurTiles(root: String, restart: Bool) throws -> Int {
        var others = persistentOthers
        let before = others.count
        others.removeAll { isOurs($0, root: root) }
        write(others, to: "persistent-others")
        try synchronize()
        if restart { restartDock() }
        return before - others.count
    }

    // MARK: Backups

    static func backupFiles(in directory: String) -> [URL] {
        let dir = URL(fileURLWithPath: Paths.expand(directory))
        guard let items = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey]) else { return [] }
        return items
            .filter { $0.pathExtension == "plist" && $0.lastPathComponent.hasPrefix("dock-") }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    static func backup(to directory: String, maxBackups: Int) throws -> URL {
        let dir = URL(fileURLWithPath: Paths.expand(directory))
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("dock-\(DateFormatter.backupStamp.string(from: Date())).plist")
        let r = Shell.run("/usr/bin/defaults", ["export", domain, url.path])
        guard r.ok, FileManager.default.fileExists(atPath: url.path) else {
            throw DockError(message: "Backup failed: \(r.stderr.trimmed)")
        }
        if maxBackups > 0 {
            for old in backupFiles(in: directory).dropFirst(maxBackups) {
                try? FileManager.default.removeItem(at: old)
            }
        }
        return url
    }

    static func restore(from url: URL, restart: Bool = true) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw DockError(message: "Backup not found: \(url.path)")
        }
        let r = Shell.run("/usr/bin/defaults", ["import", domain, url.path])
        guard r.ok else { throw DockError(message: "Restore failed: \(r.stderr.trimmed)") }
        if restart { restartDock() }
    }

    static func backupDate(_ url: URL) -> Date? {
        let name = url.deletingPathExtension().lastPathComponent
        guard name.hasPrefix("dock-") else { return nil }
        return DateFormatter.backupStamp.date(from: String(name.dropFirst(5)))
    }
}
