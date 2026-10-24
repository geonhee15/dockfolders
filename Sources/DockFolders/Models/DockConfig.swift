import Foundation

/// How a folder tile is shown by the Dock (values mirror com.apple.dock keys).
enum DockShowAs: Int, Codable, CaseIterable, Identifiable {
    case auto = 0, fan = 1, grid = 2, list = 3
    var id: Int { rawValue }
}

enum DockDisplayAs: Int, Codable, CaseIterable, Identifiable {
    case stack = 0, folder = 1
    var id: Int { rawValue }
}

enum DockArrangement: Int, Codable, CaseIterable, Identifiable {
    case name = 1, dateAdded = 2, dateModified = 3, dateCreated = 4, kind = 5
    var id: Int { rawValue }
}

struct FolderDisplay: Hashable, Codable {
    var showAs: DockShowAs = .grid
    var displayAs: DockDisplayAs = .folder
    var arrangement: DockArrangement = .name

    init() {}

    enum CodingKeys: String, CodingKey { case showAs, displayAs, arrangement }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = FolderDisplay()
        showAs = c.decode(.showAs, default: d.showAs)
        displayAs = c.decode(.displayAs, default: d.displayAs)
        arrangement = c.decode(.arrangement, default: d.arrangement)
    }
}

/// One category folder shown in the Dock.
struct DockFolder: Hashable, Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var icon: IconSpec
    /// App names (bundle file name without `.app`, display name, bundle id or absolute path).
    var apps: [String]
    /// Per-folder override of the Dock display settings.
    var display: FolderDisplay? = nil

    init(name: String, icon: IconSpec, apps: [String] = [], display: FolderDisplay? = nil) {
        self.name = name; self.icon = icon; self.apps = apps; self.display = display
    }

    enum CodingKeys: String, CodingKey { case id, name, icon, apps, display }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.decode(.id, default: UUID())
        name = c.decode(.name, default: "Folder")
        icon = c.decode(.icon, default: IconSpec())
        apps = c.decode(.apps, default: [])
        display = c.decode(.display, default: nil)
    }

    /// Folder name on disk ("Dev" or "01.Dev" when number prefixes are enabled).
    func diskName(index: Int, numberPrefix: Bool) -> String {
        let base = name.sanitizedFileName
        return numberPrefix ? String(format: "%02d.%@", index + 1, base) : base
    }
}

/// The Dock's left-hand section (`DockConfig.favorites`) is a list of app names plus these two
/// reserved tokens for the gaps the Dock calls spacer tiles.
enum PinnedToken {
    static let spacer = "<spacer>"
    static let smallSpacer = "<small-spacer>"

    static func isSpacer(_ s: String) -> Bool { s == spacer || s == smallSpacer }
}

struct AppSettings: Hashable, Codable {
    /// Where the symlink folders live (what the Dock points at).
    var foldersDirectory: String = Paths.defaultFoldersDir
    var backupDirectory: String = Paths.defaultBackupDir
    /// Write `favorites` to the Dock's app section when applying. When off the list only mirrors the Dock.
    var manageFavorites: Bool = true
    /// Legacy (≤ 2.0): one spacer after the pinned apps. Migrated into a `PinnedToken` on load, never saved again.
    var useSpacer: Bool = false
    var smallSpacer: Bool = false
    /// Keep Dock items we did not create (Downloads, other folders) in the right-hand section.
    var keepOtherDockItems: Bool = true
    /// Name folders "01.Dev", "02.AI" like v1 did.
    var numberPrefix: Bool = false
    var restartDock: Bool = true
    var defaultDisplay: FolderDisplay = FolderDisplay()
    /// Number of Dock backups to keep (0 = unlimited).
    var maxBackups: Int = 20

    init() {}

    enum CodingKeys: String, CodingKey {
        case foldersDirectory, backupDirectory, manageFavorites, useSpacer, smallSpacer,
             keepOtherDockItems, numberPrefix, restartDock, defaultDisplay, maxBackups
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings()
        foldersDirectory = c.decode(.foldersDirectory, default: d.foldersDirectory)
        backupDirectory = c.decode(.backupDirectory, default: d.backupDirectory)
        manageFavorites = c.decode(.manageFavorites, default: d.manageFavorites)
        useSpacer = c.decode(.useSpacer, default: d.useSpacer)
        smallSpacer = c.decode(.smallSpacer, default: d.smallSpacer)
        keepOtherDockItems = c.decode(.keepOtherDockItems, default: d.keepOtherDockItems)
        numberPrefix = c.decode(.numberPrefix, default: d.numberPrefix)
        restartDock = c.decode(.restartDock, default: d.restartDock)
        defaultDisplay = c.decode(.defaultDisplay, default: d.defaultDisplay)
        maxBackups = c.decode(.maxBackups, default: d.maxBackups)
    }

    /// The legacy spacer flags are read for migration but not written back.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(foldersDirectory, forKey: .foldersDirectory)
        try c.encode(backupDirectory, forKey: .backupDirectory)
        try c.encode(manageFavorites, forKey: .manageFavorites)
        try c.encode(keepOtherDockItems, forKey: .keepOtherDockItems)
        try c.encode(numberPrefix, forKey: .numberPrefix)
        try c.encode(restartDock, forKey: .restartDock)
        try c.encode(defaultDisplay, forKey: .defaultDisplay)
        try c.encode(maxBackups, forKey: .maxBackups)
    }

    var foldersDirectoryExpanded: String { Paths.expand(foldersDirectory) }
    var backupDirectoryExpanded: String { Paths.expand(backupDirectory) }
}

/// The whole user configuration (stored as JSON at ~/.config/dockfolders/config.json).
struct DockConfig: Hashable, Codable {
    static let currentVersion = 2

    var version: Int = DockConfig.currentVersion
    var folders: [DockFolder] = []
    /// The Dock's left-hand app section, in order: app names and `PinnedToken`s. See `PinnedSync`.
    var favorites: [String] = []
    var settings: AppSettings = AppSettings()

    init() {}

    init(folders: [DockFolder], favorites: [String], settings: AppSettings = AppSettings()) {
        self.folders = folders; self.favorites = favorites; self.settings = settings
    }

    enum CodingKeys: String, CodingKey { case version, folders, favorites, settings }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = c.decode(.version, default: DockConfig.currentVersion)
        folders = c.decode(.folders, default: [])
        favorites = c.decode(.favorites, default: [])
        settings = c.decode(.settings, default: AppSettings())
    }

    /// Turns the ≤ 2.0 "spacer after favorites" setting into a list item. Returns true when something changed.
    @discardableResult
    mutating func migrateLegacySpacer() -> Bool {
        guard settings.useSpacer || settings.smallSpacer else { return false }
        if settings.useSpacer, !favorites.isEmpty, !PinnedToken.isSpacer(favorites.last ?? "") {
            favorites.append(settings.smallSpacer ? PinnedToken.smallSpacer : PinnedToken.spacer)
        }
        settings.useSpacer = false
        settings.smallSpacer = false
        return true
    }

    /// Stable fingerprint of the whole config.
    var contentHash: String {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        guard let data = try? enc.encode(self) else { return UUID().uuidString }
        return String(decoding: data, as: UTF8.self).sha256Hex
    }

    /// Fingerprint of everything except the pinned apps, which are tracked against the Dock itself.
    var foldersHash: String {
        var copy = self
        copy.favorites = []
        return copy.contentHash
    }

    /// The pinned list without spacer tokens.
    var pinnedAppNames: [String] { favorites.filter { !PinnedToken.isSpacer($0) } }

    func folder(_ id: UUID) -> DockFolder? { folders.first { $0.id == id } }

    func index(of id: UUID) -> Int? { folders.firstIndex { $0.id == id } }

    /// Names of folders that contain the given app name (exact, case-insensitive).
    func foldersContaining(appName: String) -> [DockFolder] {
        folders.filter { $0.apps.contains { $0.caseInsensitiveCompare(appName) == .orderedSame } }
    }

    func diskName(for folder: DockFolder) -> String {
        let idx = index(of: folder.id) ?? 0
        return folder.diskName(index: idx, numberPrefix: settings.numberPrefix)
    }

    func diskPath(for folder: DockFolder) -> String {
        (settings.foldersDirectoryExpanded as NSString).appendingPathComponent(diskName(for: folder))
    }

    /// Validation problems a user should fix before applying.
    var problems: [String] {
        var out: [String] = []
        if folders.isEmpty { out.append("No folders defined.") }
        let names = folders.map { $0.name.sanitizedFileName.lowercased() }
        let dupes = Dictionary(grouping: names, by: { $0 }).filter { $0.value.count > 1 }.keys.sorted()
        if !dupes.isEmpty { out.append("Duplicate folder names: \(dupes.joined(separator: ", "))") }
        if folders.contains(where: { $0.name.trimmed.isEmpty }) { out.append("A folder has an empty name.") }
        return out
    }
}

/// Persisted runtime state (separate from the config so it never dirties it).
struct AppState: Codable {
    /// `DockConfig.foldersHash` at the last successful apply.
    var lastAppliedHash: String? = nil
    var lastAppliedAt: Date? = nil
    var onboarded: Bool = false
    /// The pinned list (normalized: app paths and spacer tokens) the Dock and the config last agreed on.
    /// `nil` until the first sync, when the Dock's current list is adopted.
    var pinnedBaseline: [String]? = nil

    init() {}

    enum CodingKeys: String, CodingKey { case lastAppliedHash, lastAppliedAt, onboarded, pinnedBaseline }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        lastAppliedHash = c.decode(.lastAppliedHash, default: nil)
        lastAppliedAt = c.decode(.lastAppliedAt, default: nil)
        onboarded = c.decode(.onboarded, default: false)
        pinnedBaseline = c.decode(.pinnedBaseline, default: nil)
    }
}
