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

    /// One item of the Dock's left-hand section, resolved and ready to be written.
    enum PinnedEntry {
        case app(InstalledApp)
        case spacer(small: Bool)
        /// An item we could not resolve to an installed app: its existing Dock tile is kept as-is.
        case keep(path: String)
    }

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

    /// The Dock's app section as config names, in Dock order: bundle file names for apps the catalog
    /// knows, absolute paths for apps living elsewhere, and `PinnedToken`s for spacers.
    /// Re-reads the domain first so changes made by dragging things in the Dock show up.
    static func readPinned(catalog: AppCatalog?) -> [String] {
        CFPreferencesAppSynchronize(domain as CFString)
        return persistentApps.compactMap { tile in
            switch tile["tile-type"] as? String {
            case "spacer-tile": return PinnedToken.spacer
            case "small-spacer-tile": return PinnedToken.smallSpacer
            default:
                guard let p = path(of: tile) else { return nil }
                if let app = catalog?.installedApp(atPath: p) { return app.fileName }
                return p
            }
        }
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

    /// Puts our folder tiles into the Dock and, when `pinned` is given, replaces the app section with it.
    static func apply(folders: [(path: String, label: String, display: FolderDisplay)],
                      pinned: [PinnedEntry]?,
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

        // Left-hand section. Tiles the Dock already has for an app are reused so the Dock keeps
        // its own bookkeeping (GUIDs, bookmarks) for items that merely moved.
        if let pinned {
            let existing = persistentApps
            var tiles: [Tile] = []
            var appCount = 0
            for entry in pinned {
                switch entry {
                case .app(let app):
                    appCount += 1
                    let std = (app.path as NSString).standardizingPath
                    if let reuse = existing.first(where: { ($0["tile-type"] as? String) == "file-tile" && path(of: $0) == std }) {
                        tiles.append(reuse)
                    } else {
                        tiles.append(appTile(app))
                    }
                case .spacer(let small):
                    tiles.append(spacerTile(small: small))
                case .keep(let p):
                    let std = (p as NSString).standardizingPath
                    if let reuse = existing.first(where: { path(of: $0) == std }) {
                        tiles.append(reuse)
                        appCount += 1
                        log("  · kept Dock tile \((std as NSString).lastPathComponent)")
                    } else {
                        log("  ! dropped \((std as NSString).lastPathComponent) (not installed, not in the Dock)")
                    }
                }
            }
            write(tiles, to: "persistent-apps")
            let spacers = tiles.count - appCount
            log("  ✓ \(appCount) pinned app(s)\(spacers > 0 ? " + \(spacers) spacer(s)" : "")")
        } else {
            log("  · pinned apps left untouched")
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
