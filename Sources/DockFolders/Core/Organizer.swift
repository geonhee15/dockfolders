import Foundation

/// High-level operations shared by the GUI and the CLI.
enum Organizer {
    struct Report {
        var backup: URL?
        var build: FolderBuilder.Result?
        var iconFailures: [String] = []
        var missingFavorites: [String] = []
        var resolvedFavorites: [InstalledApp] = []
        var warnings: [String] = []

        var missingApps: [(folder: String, apps: [String])] {
            (build?.folders ?? []).filter { !$0.missing.isEmpty }.map { ($0.folder.name, $0.missing) }
        }
    }

    struct OrganizeError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    /// Backup → folders → icons → Dock. `log` receives human readable progress lines.
    static func apply(config: DockConfig, catalog: AppCatalog, log: @escaping (String) -> Void) throws -> Report {
        let problems = config.problems
        if !problems.isEmpty { throw OrganizeError(message: problems.joined(separator: "\n")) }

        var report = Report()

        log("▸ Backing up Dock")
        do {
            let url = try DockManager.backup(to: config.settings.backupDirectory, maxBackups: config.settings.maxBackups)
            report.backup = url
            log("  ✓ \(Paths.abbreviate(url.path))")
        } catch {
            report.warnings.append("Backup failed: \(error.localizedDescription)")
            log("  ! backup failed: \(error.localizedDescription)")
        }

        log("▸ Creating folders")
        let build = try FolderBuilder.build(config: config, catalog: catalog, log: log)
        report.build = build

        log("▸ Rendering icons")
        for fr in build.folders {
            if IconRenderer.apply(fr.folder.icon, toFolder: fr.path, catalog: catalog) {
                log("  ✓ \(fr.folder.name)  (\(fr.folder.icon.summary))")
            } else {
                report.iconFailures.append(fr.folder.name)
                log("  ! could not set icon for \(fr.folder.name)")
            }
        }

        log("▸ Updating Dock")
        var pinned: [DockManager.PinnedEntry]? = nil
        if config.settings.manageFavorites {
            var entries: [DockManager.PinnedEntry] = []
            for name in config.favorites {
                switch name {
                case PinnedToken.spacer: entries.append(.spacer(small: false))
                case PinnedToken.smallSpacer: entries.append(.spacer(small: true))
                default:
                    if let app = catalog.find(name) {
                        entries.append(.app(app))
                        report.resolvedFavorites.append(app)
                    } else if name.hasPrefix("/") {
                        entries.append(.keep(path: Paths.expand(name)))
                    } else {
                        report.missingFavorites.append(name)
                        log("  ! pinned app not installed: \(name)")
                    }
                }
            }
            pinned = entries
        }
        let tiles = build.folders.map {
            (path: $0.path, label: config.diskName(for: $0.folder), display: $0.folder.display ?? config.settings.defaultDisplay)
        }
        try DockManager.apply(folders: tiles, pinned: pinned, settings: config.settings, log: log)
        log("✓ Done — \(build.totalLinked) apps in \(build.folders.count) folders")
        return report
    }

    /// Take the folders out of the Dock and delete the symlink folders. Leaves the pinned apps alone.
    static func removeFromDock(config: DockConfig, deleteFolders: Bool, log: @escaping (String) -> Void) throws {
        log("▸ Backing up Dock")
        if let url = try? DockManager.backup(to: config.settings.backupDirectory, maxBackups: config.settings.maxBackups) {
            log("  ✓ \(Paths.abbreviate(url.path))")
        }
        log("▸ Removing folder tiles")
        let n = try DockManager.removeOurTiles(root: config.settings.foldersDirectoryExpanded, restart: config.settings.restartDock)
        log("  ✓ removed \(n) tile(s)")
        if deleteFolders {
            log("▸ Deleting symlink folders")
            FolderBuilder.removeAll(config: config, log: log)
        }
        log("✓ Done")
    }

    /// Installed apps not referenced by any folder or pinned in the Dock.
    static func uncategorized(config: DockConfig, catalog: AppCatalog) -> [InstalledApp] {
        var referenced = Set<String>()
        for name in config.folders.flatMap(\.apps) + config.pinnedAppNames {
            if let app = catalog.find(name) { referenced.insert(app.path) }
        }
        return catalog.apps.filter { !referenced.contains($0.path) }
    }

    /// Where the Dock's folder tiles currently point versus the config (for the status badge).
    static func dockMatches(config: DockConfig) -> Bool {
        let root = config.settings.foldersDirectoryExpanded
        let current = DockManager.persistentOthers.compactMap { tile -> String? in
            guard DockManager.isOurs(tile, root: root) else { return nil }
            return DockManager.path(of: tile)
        }
        let wanted = config.folders.map { (config.diskPath(for: $0) as NSString).standardizingPath }
        return current == wanted
    }
}
