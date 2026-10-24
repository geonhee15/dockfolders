import SwiftUI
import Combine

enum SidebarItem: Hashable {
    case folder(UUID)
    case favorites
    case discover
    case backups
}

struct ApplyProgress {
    var title: String = ""
    var isRunning = false
    var log: [String] = []
    var report: Organizer.Report? = nil
    var error: String? = nil
}

/// Single source of truth for the GUI. Owns the config, the installed-app catalog and all actions.
@MainActor
final class AppModel: ObservableObject {
    @Published var config: DockConfig {
        didSet {
            if config != oldValue {
                currentHash = config.contentHash
                recomputeDerived()
                scheduleSave()
            }
        }
    }
    @Published private(set) var catalog: AppCatalog
    @Published private(set) var catalogVersion = 0
    @Published private(set) var isScanning = false
    @Published var selection: SidebarItem?
    @Published var state: AppState
    @Published var progress = ApplyProgress()
    @Published var showProgressSheet = false
    @Published var showOnboarding = false
    @Published var alertMessage: String?
    @Published private(set) var backups: [URL] = []
    @Published private(set) var uncategorized: [InstalledApp] = []
    @Published private(set) var currentHash: String = ""

    let loadSource: ConfigStore.LoadSource
    private var saveTask: Task<Void, Never>?

    init() {
        let (cfg, source) = ConfigStore.load()
        config = cfg
        loadSource = source
        state = ConfigStore.loadState()
        catalog = AppCatalog()
        selection = cfg.folders.first.map { .folder($0.id) }
        currentHash = cfg.contentHash
        showOnboarding = cfg.folders.isEmpty && !state.onboarded
        refreshBackups()
        rescan()
    }

    // MARK: Derived state

    var hasUnappliedChanges: Bool { state.lastAppliedHash != currentHash }

    var lastAppliedDescription: String? {
        guard let d = state.lastAppliedAt else { return nil }
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: d, relativeTo: Date())
    }

    func recomputeDerived() {
        uncategorized = Organizer.uncategorizedFast(config: config, catalog: catalog)
    }

    func resolve(_ name: String) -> InstalledApp? {
        catalog.find(name, spotlight: false)
    }

    // MARK: Persistence

    private func scheduleSave() {
        saveTask?.cancel()
        let snapshot = config
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            do { try ConfigStore.save(snapshot) } catch {
                self?.alertMessage = "\(L("Could not save config")): \(error.localizedDescription)"
            }
        }
    }

    func saveNow() {
        saveTask?.cancel()
        try? ConfigStore.save(config)
    }

    // MARK: Catalog

    func rescan() {
        guard !isScanning else { return }
        isScanning = true
        let dir = config.settings.foldersDirectory
        Task.detached(priority: .userInitiated) {
            let apps = AppCatalog.scan(excluding: dir)
            await MainActor.run {
                self.catalog.setApps(apps)
                self.catalogVersion += 1
                self.isScanning = false
                self.recomputeDerived()
            }
        }
    }

    // MARK: Folders

    @discardableResult
    func addFolder(name: String? = nil, emoji: String = "📁", apps: [String] = [], select: Bool = true) -> UUID {
        var base = name ?? L("New Folder")
        var n = 2
        while config.folders.contains(where: { $0.name.caseInsensitiveCompare(base) == .orderedSame }) {
            base = "\(name ?? L("New Folder")) \(n)"; n += 1
        }
        let folder = DockFolder(name: base, icon: IconSpec(emoji: emoji, palette: config.folders.count), apps: apps)
        config.folders.append(folder)
        if select { selection = .folder(folder.id) }
        return folder.id
    }

    func deleteFolder(_ id: UUID) {
        guard let i = config.index(of: id) else { return }
        config.folders.remove(at: i)
        if selection == .folder(id) {
            selection = config.folders.isEmpty ? nil : .folder(config.folders[min(i, config.folders.count - 1)].id)
        }
    }

    func duplicateFolder(_ id: UUID) {
        guard let i = config.index(of: id) else { return }
        var copy = config.folders[i]
        copy.id = UUID()
        copy.name = "\(copy.name) \(L("copy"))"
        config.folders.insert(copy, at: i + 1)
        selection = .folder(copy.id)
    }

    func moveFolders(from: IndexSet, to: Int) {
        config.folders.move(fromOffsets: from, toOffset: to)
    }

    func folderBinding(_ id: UUID) -> Binding<DockFolder> {
        Binding(
            get: { self.config.folder(id) ?? DockFolder(name: "", icon: IconSpec()) },
            set: { new in if let i = self.config.index(of: id) { self.config.folders[i] = new } }
        )
    }

    // MARK: Apps in folders

    /// Accepts app names or paths (e.g. from a Finder drop); stores canonical bundle names.
    func addApps(_ namesOrPaths: [String], to id: UUID) {
        guard let i = config.index(of: id) else { return }
        var existing = config.folders[i].apps
        for raw in namesOrPaths {
            let name: String
            if raw.hasPrefix("/") {
                guard raw.hasSuffix(".app") || raw.hasSuffix(".app/"), let app = catalog.app(atPath: Paths.expand(raw).trimmingCharacters(in: CharacterSet(charactersIn: "/"))) else { continue }
                name = app.fileName
            } else {
                name = catalog.find(raw, spotlight: false)?.fileName ?? raw
            }
            if !existing.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
                existing.append(name)
            }
        }
        config.folders[i].apps = existing
    }

    func removeApps(_ names: Set<String>, from id: UUID) {
        guard let i = config.index(of: id) else { return }
        config.folders[i].apps.removeAll { names.contains($0) }
    }

    func moveApp(_ name: String, from: UUID, to: UUID) {
        removeApps([name], from: from)
        addApps([name], to: to)
    }

    func newFolder(withApp app: InstalledApp) {
        addFolder(name: app.displayName, apps: [app.fileName])
    }

    // MARK: Favorites

    func addFavorites(_ names: [String]) {
        for n in names where !config.favorites.contains(where: { $0.caseInsensitiveCompare(n) == .orderedSame }) {
            config.favorites.append(n)
        }
    }

    func removeFavorites(_ names: Set<String>) {
        config.favorites.removeAll { names.contains($0) }
    }

    func moveFavorites(from: IndexSet, to: Int) {
        config.favorites.move(fromOffsets: from, toOffset: to)
    }

    // MARK: Presets / import / export

    func loadPreset(_ preset: Preset, replace: Bool) {
        let fresh = preset.makeConfig(keeping: config.settings)
        if replace {
            config = fresh
        } else {
            let offset = config.folders.count
            config.folders.append(contentsOf: fresh.folders.enumerated().map { i, f in
                var f = f
                f.icon = IconSpec(emoji: f.icon.emoji, palette: offset + i)
                return f
            })
            addFavorites(fresh.favorites)
        }
        selection = config.folders.first.map { .folder($0.id) }
        state.onboarded = true
        ConfigStore.saveState(state)
    }

    func startEmpty() {
        state.onboarded = true
        ConfigStore.saveState(state)
        if config.folders.isEmpty { addFolder(name: L("Work"), emoji: "💼") }
    }

    func importLegacy(url: URL) {
        do {
            config = try LegacyImporter.importConfig(at: url, into: config.settings)
            selection = config.folders.first.map { .folder($0.id) }
            state.onboarded = true
            ConfigStore.saveState(state)
        } catch { alertMessage = error.localizedDescription }
    }

    func importJSON(url: URL) {
        do {
            config = try ConfigStore.load(from: url)
            selection = config.folders.first.map { .folder($0.id) }
        } catch { alertMessage = error.localizedDescription }
    }

    func exportJSON(url: URL) {
        do { try ConfigStore.export(config, to: url) } catch { alertMessage = error.localizedDescription }
    }

    // MARK: Dock actions

    func apply() {
        guard !progress.isRunning else { return }
        let problems = config.problems
        if !problems.isEmpty { alertMessage = problems.joined(separator: "\n"); return }
        saveNow()
        let cfg = config
        let cat = catalog
        progress = ApplyProgress(title: L("Applying to Dock…"), isRunning: true)
        showProgressSheet = true
        Task.detached(priority: .userInitiated) {
            do {
                let report = try Organizer.apply(config: cfg, catalog: cat) { line in
                    DispatchQueue.main.async { self.progress.log.append(line) }
                }
                await MainActor.run {
                    self.progress.report = report
                    self.progress.isRunning = false
                    self.progress.title = L("Applied to Dock")
                    self.state.lastAppliedHash = cfg.contentHash
                    self.state.lastAppliedAt = Date()
                    ConfigStore.saveState(self.state)
                    self.refreshBackups()
                    self.catalogVersion += 1
                }
            } catch {
                await MainActor.run {
                    self.progress.error = error.localizedDescription
                    self.progress.isRunning = false
                    self.progress.title = L("Failed")
                }
            }
        }
    }

    func removeFromDock(deleteFolders: Bool) {
        guard !progress.isRunning else { return }
        let cfg = config
        progress = ApplyProgress(title: L("Removing from Dock…"), isRunning: true)
        showProgressSheet = true
        Task.detached(priority: .userInitiated) {
            do {
                try Organizer.removeFromDock(config: cfg, deleteFolders: deleteFolders) { line in
                    DispatchQueue.main.async { self.progress.log.append(line) }
                }
                await MainActor.run {
                    self.progress.isRunning = false
                    self.progress.title = L("Removed from Dock")
                    self.state.lastAppliedHash = nil
                    ConfigStore.saveState(self.state)
                    self.refreshBackups()
                }
            } catch {
                await MainActor.run {
                    self.progress.error = error.localizedDescription
                    self.progress.isRunning = false
                    self.progress.title = L("Failed")
                }
            }
        }
    }

    // MARK: Backups

    func refreshBackups() {
        backups = DockManager.backupFiles(in: config.settings.backupDirectory)
    }

    func backupNow() {
        do {
            _ = try DockManager.backup(to: config.settings.backupDirectory, maxBackups: config.settings.maxBackups)
            refreshBackups()
        } catch { alertMessage = error.localizedDescription }
    }

    func restore(_ url: URL) {
        do {
            try DockManager.restore(from: url, restart: config.settings.restartDock)
            state.lastAppliedHash = nil
            ConfigStore.saveState(state)
        } catch { alertMessage = error.localizedDescription }
    }

    func deleteBackup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
        refreshBackups()
    }

    // MARK: Finder helpers

    func revealFoldersDirectory() {
        let path = config.settings.foldersDirectoryExpanded
        if FileManager.default.fileExists(atPath: path) {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
        } else {
            alertMessage = L("The folders haven't been created yet. Apply to Dock first.")
        }
    }

    func revealConfigFolder() {
        Paths.ensureDir(Paths.configDir)
        NSWorkspace.shared.selectFile(Paths.configFile.path, inFileViewerRootedAtPath: Paths.configDir.path)
    }

    func reveal(app: InstalledApp) {
        NSWorkspace.shared.selectFile(app.path, inFileViewerRootedAtPath: (app.path as NSString).deletingLastPathComponent)
    }
}

extension Organizer {
    /// Like `uncategorized` but never hits Spotlight (safe on the main thread).
    static func uncategorizedFast(config: DockConfig, catalog: AppCatalog) -> [InstalledApp] {
        var referenced = Set<String>()
        for name in config.folders.flatMap(\.apps) + config.favorites {
            if let app = catalog.find(name, spotlight: false) { referenced.insert(app.path) }
        }
        return catalog.apps.filter { !referenced.contains($0.path) }
    }
}
