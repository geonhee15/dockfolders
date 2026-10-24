import Foundation

/// Loads and saves the JSON config, runtime state and user-supplied icon images.
enum ConfigStore {
    enum LoadSource { case json, legacyImported, fresh }

    static func load() -> (config: DockConfig, source: LoadSource) {
        let fm = FileManager.default
        if fm.fileExists(atPath: Paths.configFile.path) {
            do {
                let data = try Data(contentsOf: Paths.configFile)
                var cfg = try JSONDecoder().decode(DockConfig.self, from: data)
                cfg.version = DockConfig.currentVersion
                if cfg.migrateLegacySpacer() { try? save(cfg) }
                return (cfg, .json)
            } catch {
                // Keep a copy of the unreadable file so nothing is lost, then fall through.
                let broken = Paths.configDir.appendingPathComponent("config.broken-\(DateFormatter.backupStamp.string(from: Date())).json")
                try? fm.moveItem(at: Paths.configFile, to: broken)
            }
        }
        if fm.fileExists(atPath: Paths.legacyConfigFile.path),
           let cfg = try? LegacyImporter.importConfig(at: Paths.legacyConfigFile) {
            try? save(cfg)
            return (cfg, .legacyImported)
        }
        return (DockConfig(), .fresh)
    }

    static func load(from url: URL) throws -> DockConfig {
        let data = try Data(contentsOf: url)
        var cfg = try JSONDecoder().decode(DockConfig.self, from: data)
        cfg.migrateLegacySpacer()
        return cfg
    }

    static func save(_ config: DockConfig) throws {
        Paths.ensureDir(Paths.configDir)
        try encode(config).write(to: Paths.configFile, options: .atomic)
    }

    static func export(_ config: DockConfig, to url: URL) throws {
        try encode(config).write(to: url, options: .atomic)
    }

    static func encode(_ config: DockConfig) throws -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        return try enc.encode(config)
    }

    // MARK: State

    static func loadState() -> AppState {
        guard let data = try? Data(contentsOf: Paths.stateFile) else { return AppState() }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return (try? dec.decode(AppState.self, from: data)) ?? AppState()
    }

    static func saveState(_ state: AppState) {
        Paths.ensureDir(Paths.configDir)
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        if let data = try? enc.encode(state) {
            try? data.write(to: Paths.stateFile, options: .atomic)
        }
    }

    // MARK: Images

    /// Copies a user-chosen image into the config folder so the config stays self-contained.
    static func importImage(from source: URL) throws -> String {
        Paths.ensureDir(Paths.imagesDir)
        let ext = source.pathExtension.isEmpty ? "png" : source.pathExtension
        let dest = Paths.imagesDir.appendingPathComponent("\(UUID().uuidString).\(ext)")
        try FileManager.default.copyItem(at: source, to: dest)
        return dest.path
    }

    /// Deletes images in the images folder that no folder references anymore.
    static func pruneUnusedImages(config: DockConfig) {
        let used = Set(config.folders.compactMap { $0.icon.imagePath })
        guard let items = try? FileManager.default.contentsOfDirectory(at: Paths.imagesDir, includingPropertiesForKeys: nil) else { return }
        for item in items where !used.contains(item.path) {
            try? FileManager.default.removeItem(at: item)
        }
    }
}
