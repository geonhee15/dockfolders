import Foundation
import AppKit

/// Finds installed applications and resolves the names used in the config to bundles.
final class AppCatalog {
    private(set) var apps: [InstalledApp] = []
    private var byLowerName: [String: InstalledApp] = [:]
    private var byPath: [String: InstalledApp] = [:]
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
        byPath = [:]
        for app in apps {
            byLowerName[app.fileName.lowercased()] = byLowerName[app.fileName.lowercased()] ?? app
            byLowerName[app.displayName.lowercased()] = byLowerName[app.displayName.lowercased()] ?? app
            if let b = app.bundleID { byLowerName[b.lowercased()] = byLowerName[b.lowercased()] ?? app }
            byPath[app.path] = app
        }
        negativeCache.removeAll()
    }

    // MARK: Scanning

    /// Walks the search roots. Symlinks to app bundles count as apps at the link's path (Safari lives
    /// in a cryptex behind `/Applications/Safari.app`; Homebrew casks link into /Applications too);
    /// a bundle reachable under two paths is listed once, under the first path found.
    static func scan(excluding foldersDirectory: String? = nil) -> [InstalledApp] {
        let fm = FileManager.default
        var found: [String: InstalledApp] = [:]
        var seenReal = Set<String>()
        let excluded = foldersDirectory.map { Paths.expand($0) }

        func visit(_ dir: String, depth: Int) {
            guard depth <= 2, let items = try? fm.contentsOfDirectory(atPath: dir) else { return }
            for item in items where !item.hasPrefix(".") {
                let path = (dir as NSString).appendingPathComponent(item)
                if let ex = excluded, path == ex || path.hasPrefix(ex + "/") { continue }
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else { continue }
                let isLink = (try? fm.attributesOfItem(atPath: path))
                    .map { ($0[.type] as? FileAttributeType) == .typeSymbolicLink } ?? false
                if item.hasSuffix(".app") {
                    let real = (path as NSString).resolvingSymlinksInPath
                    guard !seenReal.contains(real) else { continue }
                    seenReal.insert(real)
                    if found[path] == nil, let app = describe(path) { found[path] = app }
                } else if depth < 2, !isLink {
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
        let raw = query.trimmed
        guard !raw.isEmpty else { return nil }
        if raw.hasPrefix("/") || raw.hasPrefix("~") {
            let p = Paths.expand(raw)
            for candidate in [p, p.hasSuffix(".app") ? nil : p + ".app"].compactMap({ $0 })
            where FileManager.default.fileExists(atPath: candidate) {
                return installedApp(atPath: candidate) ?? AppCatalog.describe(candidate)
            }
            return nil
        }
        let q = raw.strippingAppExtension
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
        installedApp(atPath: path) ?? AppCatalog.describe(path)
    }

    /// Only apps found by the scan (nil for bundles living outside the search roots). Accepts either
    /// the scanned path or the path it resolves to.
    func installedApp(atPath path: String) -> InstalledApp? {
        let std = (path as NSString).standardizingPath
        lock.lock(); defer { lock.unlock() }
        if let hit = byPath[std] { return hit }
        let real = (std as NSString).resolvingSymlinksInPath
        return apps.first { ($0.path as NSString).resolvingSymlinksInPath == real }
    }

    // MARK: Icons

    func icon(forPath path: String) -> NSImage {
        if let hit = iconCache.object(forKey: path as NSString) { return hit }
        let img = NSWorkspace.shared.icon(forFile: path)
        iconCache.setObject(img, forKey: path as NSString)
        return img
    }
}
