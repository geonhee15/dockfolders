import Foundation
import AppKit

/// Finds installed applications and resolves the names used in the config to bundles.
final class AppCatalog {
    private(set) var apps: [InstalledApp] = []
    private var byLowerName: [String: InstalledApp] = [:]
    private var negativeCache = Set<String>()
    private let iconCache = NSCache<NSString, NSImage>()
    private let lock = NSLock()

    /// Directories scanned for `.app` bundles (two levels deep, so "Adobe X/Adobe X.app" is found).
    static var searchRoots: [String] {
        [
            "/Applications",
            "/System/Applications",
            "/System/Applications/Utilities",
            "/Applications/Utilities",
            "/Applications/Setapp",
            "/System/Library/CoreServices/Applications",
            NSHomeDirectory() + "/Applications",
        ]
    }

    init(apps: [InstalledApp] = []) {
        setApps(apps)
    }

    static func scanned(excluding foldersDirectory: String? = nil) -> AppCatalog {
        AppCatalog(apps: scan(excluding: foldersDirectory))
    }

    func setApps(_ list: [InstalledApp]) {
        lock.lock(); defer { lock.unlock() }
        apps = list.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        byLowerName = [:]
        for app in apps {
            byLowerName[app.fileName.lowercased()] = byLowerName[app.fileName.lowercased()] ?? app
            byLowerName[app.displayName.lowercased()] = byLowerName[app.displayName.lowercased()] ?? app
            if let b = app.bundleID { byLowerName[b.lowercased()] = byLowerName[b.lowercased()] ?? app }
        }
        negativeCache.removeAll()
    }

    // MARK: Scanning

    static func scan(excluding foldersDirectory: String? = nil) -> [InstalledApp] {
        let fm = FileManager.default
        var found: [String: InstalledApp] = [:]
        let excluded = foldersDirectory.map { Paths.expand($0) }

        func visit(_ dir: String, depth: Int) {
            guard depth <= 2, let items = try? fm.contentsOfDirectory(atPath: dir) else { return }
            for item in items where !item.hasPrefix(".") {
                let path = (dir as NSString).appendingPathComponent(item)
                if let ex = excluded, path == ex || path.hasPrefix(ex + "/") { continue }
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else { continue }
                if let attrs = try? fm.attributesOfItem(atPath: path),
                   (attrs[.type] as? FileAttributeType) == .typeSymbolicLink { continue }
                if item.hasSuffix(".app") {
                    if found[path] == nil, let app = describe(path) { found[path] = app }
                } else if depth < 2 {
                    visit(path, depth: depth + 1)
                }
            }
        }
        for root in searchRoots { visit(root, depth: 0) }
        return Array(found.values)
    }

    static func describe(_ path: String) -> InstalledApp? {
        let fileName = ((path as NSString).lastPathComponent).strippingAppExtension
        var display = FileManager.default.displayName(atPath: path).strippingAppExtension
        var bundleID: String? = nil
        if let bundle = Bundle(path: path) {
            bundleID = bundle.bundleIdentifier
            if display.isEmpty {
                display = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                    ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String) ?? fileName
            }
        }
        if display.isEmpty { display = fileName }
        return InstalledApp(path: path, fileName: fileName, displayName: display, bundleID: bundleID)
    }

    // MARK: Lookup

    /// Resolve a config name to an installed app. Falls back to Spotlight for apps living elsewhere.
    func find(_ query: String, spotlight: Bool = true) -> InstalledApp? {
        let q = query.trimmed.strippingAppExtension
        guard !q.isEmpty else { return nil }
        if q.hasPrefix("/") || q.hasPrefix("~") {
            let p = Paths.expand(q)
            if FileManager.default.fileExists(atPath: p) { return AppCatalog.describe(p) }
            return nil
        }
        lock.lock()
        let cached = byLowerName[q.lowercased()]
        let negative = negativeCache.contains(q.lowercased())
        lock.unlock()
        if let cached { return cached }
        if negative || !spotlight { return nil }

        if let viaSpotlight = AppCatalog.spotlight(q) {
            lock.lock()
            byLowerName[q.lowercased()] = viaSpotlight
            lock.unlock()
            return viaSpotlight
        }
        lock.lock(); negativeCache.insert(q.lowercased()); lock.unlock()
        return nil
    }

    private static func spotlight(_ name: String) -> InstalledApp? {
        guard FileManager.default.isExecutableFile(atPath: "/usr/bin/mdfind") else { return nil }
        let escaped = name.replacingOccurrences(of: "'", with: "\\'")
        let queries = [
            "kMDItemContentType == 'com.apple.application-bundle' && kMDItemFSName == '\(escaped).app'",
            "kMDItemContentType == 'com.apple.application-bundle' && kMDItemDisplayName == '\(escaped)'",
        ]
        for q in queries {
            let r = Shell.run("/usr/bin/mdfind", [q], timeout: 8)
            let hits = r.stdout.split(separator: "\n").map(String.init)
                .filter { !$0.contains("/Library/Developer/") && !$0.contains("/.Trash/") && !$0.contains("/Backups.backupdb/") }
            if let first = hits.first, FileManager.default.fileExists(atPath: first) {
                return describe(first)
            }
        }
        return nil
    }

    func app(atPath path: String) -> InstalledApp? {
        apps.first { $0.path == path } ?? AppCatalog.describe(path)
    }

    // MARK: Icons

    func icon(forPath path: String) -> NSImage {
        if let hit = iconCache.object(forKey: path as NSString) { return hit }
        let img = NSWorkspace.shared.icon(forFile: path)
        iconCache.setObject(img, forKey: path as NSString)
        return img
    }
}
