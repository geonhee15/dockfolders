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

struct AppSettings: Hashable, Codable {
    /// Where the symlink folders live (what the Dock points at).
    var foldersDirectory: String = Paths.defaultFoldersDir
    var backupDirectory: String = Paths.defaultBackupDir
    /// Replace the Dock's app section with `favorites`.
    var manageFavorites: Bool = true
    var useSpacer: Bool = true
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

    var foldersDirectoryExpanded: String { Paths.expand(foldersDirectory) }
    var backupDirectoryExpanded: String { Paths.expand(backupDirectory) }
}

/// The whole user configuration (stored as JSON at ~/.config/dockfolders/config.json).
struct DockConfig: Hashable, Codable {
    static let currentVersion = 2

    var version: Int = DockConfig.currentVersion
    var folders: [DockFolder] = []
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

    /// Stable fingerprint used to tell whether the Dock reflects this config.
    var contentHash: String {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        guard let data = try? enc.encode(self) else { return UUID().uuidString }
        return String(decoding: data, as: UTF8.self).sha256Hex
    }

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
    var lastAppliedHash: String? = nil
    var lastAppliedAt: Date? = nil
    var onboarded: Bool = false

    init() {}

    enum CodingKeys: String, CodingKey { case lastAppliedHash, lastAppliedAt, onboarded }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        lastAppliedHash = c.decode(.lastAppliedHash, default: nil)
        lastAppliedAt = c.decode(.lastAppliedAt, default: nil)
        onboarded = c.decode(.onboarded, default: false)
    }
}
