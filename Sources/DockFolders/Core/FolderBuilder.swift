import Foundation

/// Creates the on-disk category folders full of symlinks that the Dock displays.
enum FolderBuilder {
    struct FolderResult {
        let folder: DockFolder
        let path: String
        var linked: [InstalledApp] = []
        var missing: [String] = []
    }

    struct Result {
        var folders: [FolderResult] = []
        var removedStale: [String] = []
        var keptUnknown: [String] = []
        var totalLinked: Int { folders.reduce(0) { $0 + $1.linked.count } }
        var totalMissing: Int { folders.reduce(0) { $0 + $1.missing.count } }
    }

    struct BuildError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    static func build(config: DockConfig, catalog: AppCatalog, log: (String) -> Void = { _ in }) throws -> Result {
        let fm = FileManager.default
        let root = config.settings.foldersDirectoryExpanded
        guard !root.isEmpty, root != "/", root != Paths.home else {
            throw BuildError(message: "Refusing to use \(root) as the folders directory.")
        }
        do {
            try fm.createDirectory(atPath: root, withIntermediateDirectories: true)
        } catch {
            throw BuildError(message: "Could not create \(root): \(error.localizedDescription)")
        }

        var result = Result()
        let desired = config.folders.enumerated().map { $0.element.diskName(index: $0.offset, numberPrefix: config.settings.numberPrefix) }

        // 1. Remove folders we previously created that are no longer wanted (only if they hold just symlinks).
        if let existing = try? fm.contentsOfDirectory(atPath: root) {
            for item in existing where !item.hasPrefix(".") && !desired.contains(item) {
                let path = (root as NSString).appendingPathComponent(item)
                if isSafeToRemove(path) {
                    try? fm.removeItem(atPath: path)
                    result.removedStale.append(item)
                    log("  − removed stale folder \(item)")
                } else {
                    result.keptUnknown.append(item)
                    log("  ! kept \(item) (contains real files)")
                }
            }
        }

        // 2. Create / sync each folder.
        for (i, folder) in config.folders.enumerated() {
            let dirName = desired[i]
            let dir = (root as NSString).appendingPathComponent(dirName)
            try? fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
            var fr = FolderResult(folder: folder, path: dir)

            var wantedLinks: [String: String] = [:] // linkName -> target
            for appName in folder.apps {
                if let app = catalog.find(appName) {
                    let linkName = (app.path as NSString).lastPathComponent
                    wantedLinks[linkName] = app.path
                    fr.linked.append(app)
                } else {
                    fr.missing.append(appName)
                }
            }

            // Drop symlinks that are no longer wanted (never touch real files).
            if let items = try? fm.contentsOfDirectory(atPath: dir) {
                for item in items where item != "Icon\r" && !item.hasPrefix(".") {
                    let p = (dir as NSString).appendingPathComponent(item)
                    guard isSymlink(p) else { continue }
                    if wantedLinks[item] == nil { try? fm.removeItem(atPath: p) }
                }
            }
            for (linkName, target) in wantedLinks {
                let p = (dir as NSString).appendingPathComponent(linkName)
                if isSymlink(p) {
                    if (try? fm.destinationOfSymbolicLink(atPath: p)) == target { continue }
                    try? fm.removeItem(atPath: p)
                } else if fm.fileExists(atPath: p) {
                    continue // a real file with that name; leave it alone
                }
                try? fm.createSymbolicLink(atPath: p, withDestinationPath: target)
            }

            var line = String(format: "  ✓ %-18@ %2d apps", dirName as NSString, fr.linked.count)
            if !fr.missing.isEmpty { line += "  (not installed: \(fr.missing.joined(separator: ", ")))" }
            log(line)
            result.folders.append(fr)
        }
        return result
    }

    /// Removes everything DockFolders created on disk (used by "Remove from Dock").
    static func removeAll(config: DockConfig, log: (String) -> Void = { _ in }) {
        let fm = FileManager.default
        let root = config.settings.foldersDirectoryExpanded
        guard let items = try? fm.contentsOfDirectory(atPath: root) else { return }
        for item in items where !item.hasPrefix(".") {
            let path = (root as NSString).appendingPathComponent(item)
            if isSafeToRemove(path) {
                try? fm.removeItem(atPath: path)
                log("  − removed \(item)")
            } else {
                log("  ! kept \(item) (contains real files)")
            }
        }
        if let left = try? fm.contentsOfDirectory(atPath: root), left.filter({ !$0.hasPrefix(".") }).isEmpty {
            try? fm.removeItem(atPath: root)
        }
    }

    static func isSymlink(_ path: String) -> Bool {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path) else { return false }
        return (attrs[.type] as? FileAttributeType) == .typeSymbolicLink
    }

    /// A folder is ours if it only contains symlinks, the custom icon resource and Finder metadata.
    static func isSafeToRemove(_ path: String) -> Bool {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDir) else { return false }
        if !isDir.boolValue { return isSymlink(path) }
        guard let items = try? fm.contentsOfDirectory(atPath: path) else { return false }
        for item in items {
            if item == "Icon\r" || item == ".DS_Store" { continue }
            if !isSymlink((path as NSString).appendingPathComponent(item)) { return false }
        }
        return true
    }
}
