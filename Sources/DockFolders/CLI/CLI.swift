import Foundation
import AppKit

/// Terminal front-end. The same binary that runs the GUI handles `dockfolders <command>`.
enum CLI {
    static let commands: Set<String> = [
        "apply", "organize", "reset", "restore", "discover", "list", "preset", "import", "backup", "backups",
        "remove", "render-icon", "export", "help", "--help", "-h", "version", "--version", "-v",
        "--render-app-icon", "--snapshot-ui",
    ]

    static func isCLIInvocation(_ args: [String]) -> Bool {
        guard let first = args.first else { return false }
        return commands.contains(first)
    }

    private static var tty: Bool { isatty(STDOUT_FILENO) != 0 }
    private static func c(_ code: String, _ s: String) -> String { tty ? "\u{1B}[\(code)m\(s)\u{1B}[0m" : s }
    private static func bold(_ s: String) -> String { c("1", s) }
    private static func green(_ s: String) -> String { c("0;32", s) }
    private static func yellow(_ s: String) -> String { c("1;33", s) }
    private static func red(_ s: String) -> String { c("0;31", s) }
    private static func dim(_ s: String) -> String { c("2", s) }
    private static func cyan(_ s: String) -> String { c("0;36", s) }

    static func run(_ args: [String]) -> Int32 {
        var args = args
        let cmd = args.removeFirst()
        do {
            switch cmd {
            case "apply", "organize": return try cmdApply(args)
            case "reset", "restore": return try cmdRestore(args)
            case "discover": return cmdDiscover()
            case "list": return cmdList()
            case "preset": return try cmdPreset(args)
            case "import": return try cmdImport(args)
            case "backup": return try cmdBackup()
            case "backups": return cmdBackups()
            case "remove": return try cmdRemove(args)
            case "render-icon": return try cmdRenderIcon(args)
            case "export": return try cmdExport(args)
            case "version", "--version", "-v": print("dockfolders \(AppInfo.version)"); return 0
            case "--render-app-icon": return try cmdRenderAppIcon(args)
            case "--snapshot-ui": return UISnapshot.run(args)
            default: printHelp(); return 0
            }
        } catch {
            FileHandle.standardError.write(Data((red("✗ ") + error.localizedDescription + "\n").utf8))
            return 1
        }
    }

    // MARK: Commands

    static func loadConfig(_ args: inout [String]) throws -> DockConfig {
        if let i = args.firstIndex(of: "--config"), i + 1 < args.count {
            let url = URL(fileURLWithPath: Paths.expand(args[i + 1]))
            args.removeSubrange(i...(i + 1))
            if url.pathExtension == "sh" { return try LegacyImporter.importConfig(at: url) }
            return try ConfigStore.load(from: url)
        }
        let (cfg, source) = ConfigStore.load()
        switch source {
        case .legacyImported: print(yellow("ℹ") + " Imported legacy config.sh → \(Paths.abbreviate(Paths.configFile.path))")
        case .fresh: print(yellow("ℹ") + " No config yet. Open the app, or run: dockfolders preset <name>")
        case .json: break
        }
        return cfg
    }

    static func cmdApply(_ argsIn: [String]) throws -> Int32 {
        var args = argsIn
        let config = try loadConfig(&args)
        if config.folders.isEmpty {
            print(red("✗") + " No folders defined. Try: dockfolders preset developer")
            return 1
        }
        banner()
        let catalog = AppCatalog.scanned(excluding: config.settings.foldersDirectory)
        let report = try Organizer.apply(config: config, catalog: catalog) { print(colorize($0)) }
        var state = ConfigStore.loadState()
        state.lastAppliedHash = config.contentHash
        state.lastAppliedAt = Date()
        ConfigStore.saveState(state)
        if !report.missingApps.isEmpty {
            print("\n" + yellow("Not installed (skipped):"))
            for m in report.missingApps { print("  \(m.folder): \(m.apps.joined(separator: ", "))") }
        }
        print("\n" + dim("Undo: dockfolders reset"))
        return 0
    }

    static func cmdRestore(_ args: [String]) throws -> Int32 {
        let (config, _) = ConfigStore.load()
        let url: URL
        if let given = args.first {
            url = URL(fileURLWithPath: Paths.expand(given))
        } else {
            guard let latest = DockManager.backupFiles(in: config.settings.backupDirectory).first else {
                print(red("✗") + " No backups in \(config.settings.backupDirectory)")
                return 1
            }
            url = latest
        }
        print("Restoring \(Paths.abbreviate(url.path))")
        try DockManager.restore(from: url)
        print(green("✓") + " Dock restored")
        return 0
    }

    static func cmdDiscover() -> Int32 {
        let (config, _) = ConfigStore.load()
        let catalog = AppCatalog.scanned(excluding: config.settings.foldersDirectory)
        let apps = Organizer.uncategorized(config: config, catalog: catalog)
        if apps.isEmpty { print(green("✓") + " All \(catalog.apps.count) apps are categorized"); return 0 }
        print(yellow("\(apps.count) of \(catalog.apps.count) apps are not in any folder:"))
        for app in apps {
            let extra = app.displayName != app.fileName ? dim("  (\(app.displayName))") : ""
            print("  • \(app.fileName)\(extra)  " + dim(Paths.abbreviate((app.path as NSString).deletingLastPathComponent)))
        }
        return 0
    }

    static func cmdList() -> Int32 {
        let (config, _) = ConfigStore.load()
        print(bold("Folders") + dim("  (\(Paths.abbreviate(Paths.configFile.path)))"))
        for (i, f) in config.folders.enumerated() {
            let glyph = f.icon.source == .emoji ? f.icon.emoji : "·"
            print("  \(glyph) " + bold(f.diskName(index: i, numberPrefix: config.settings.numberPrefix)) + dim("  \(f.apps.count) apps"))
            print("     " + dim(f.apps.joined(separator: ", ")))
        }
        print(bold("Favorites") + (config.settings.manageFavorites ? "" : dim("  (not managed)")))
        print("  " + config.favorites.joined(separator: ", "))
        return 0
    }

    static func cmdPreset(_ args: [String]) throws -> Int32 {
        guard let name = args.first, let preset = Presets.named(name) else {
            print("Usage: dockfolders preset <name>\nAvailable: " + Presets.all.map(\.id).joined(separator: ", "))
            return 1
        }
        let (old, _) = ConfigStore.load()
        let cfg = preset.makeConfig(keeping: old.settings)
        try ConfigStore.save(cfg)
        print(green("✓") + " Applied preset \(preset.name) (\(cfg.folders.count) folders). Next: dockfolders apply")
        return 0
    }

    static func cmdImport(_ args: [String]) throws -> Int32 {
        let path = args.first.map(Paths.expand) ?? Paths.legacyConfigFile.path
        let cfg = try LegacyImporter.importConfig(at: URL(fileURLWithPath: path))
        try ConfigStore.save(cfg)
        print(green("✓") + " Imported \(cfg.folders.count) folders, \(cfg.favorites.count) favorites → \(Paths.abbreviate(Paths.configFile.path))")
        return 0
    }

    static func cmdBackup() throws -> Int32 {
        let (config, _) = ConfigStore.load()
        let url = try DockManager.backup(to: config.settings.backupDirectory, maxBackups: config.settings.maxBackups)
        print(green("✓") + " " + Paths.abbreviate(url.path))
        return 0
    }

    static func cmdBackups() -> Int32 {
        let (config, _) = ConfigStore.load()
        let files = DockManager.backupFiles(in: config.settings.backupDirectory)
        if files.isEmpty { print("No backups in \(config.settings.backupDirectory)"); return 0 }
        let df = DateFormatter(); df.dateStyle = .medium; df.timeStyle = .short
        for f in files {
            let date = DockManager.backupDate(f).map { df.string(from: $0) } ?? "?"
            print("  \(date)  " + dim(Paths.abbreviate(f.path)))
        }
        return 0
    }

    static func cmdRemove(_ args: [String]) throws -> Int32 {
        let (config, _) = ConfigStore.load()
        try Organizer.removeFromDock(config: config, deleteFolders: args.contains("--delete-folders")) { print(colorize($0)) }
        return 0
    }

    static func cmdRenderIcon(_ args: [String]) throws -> Int32 {
        guard args.count >= 2 else {
            print("Usage: dockfolders render-icon <folder-name|emoji> <out.png> [size]")
            return 1
        }
        let (config, _) = ConfigStore.load()
        let size = args.count >= 3 ? Int(args[2]) ?? 512 : 512
        let spec: IconSpec
        if let f = config.folders.first(where: { $0.name.caseInsensitiveCompare(args[0]) == .orderedSame }) {
            spec = f.icon
        } else {
            spec = IconSpec(emoji: args[0], palette: 0)
        }
        let catalog = AppCatalog.scanned(excluding: config.settings.foldersDirectory)
        try IconRenderer.writePNG(spec, pixelSize: size, to: URL(fileURLWithPath: Paths.expand(args[1])), catalog: catalog)
        print(green("✓") + " \(args[1])")
        return 0
    }

    static func cmdExport(_ args: [String]) throws -> Int32 {
        let (config, _) = ConfigStore.load()
        let data = try ConfigStore.encode(config)
        if let path = args.first {
            try data.write(to: URL(fileURLWithPath: Paths.expand(path)))
            print(green("✓") + " \(path)")
        } else {
            print(String(decoding: data, as: UTF8.self))
        }
        return 0
    }

    static func cmdRenderAppIcon(_ args: [String]) throws -> Int32 {
        guard let out = args.first else { print("Usage: --render-app-icon <dir.iconset>"); return 1 }
        try IconRenderer.writeIconset(IconRenderer.appIconSpec, to: URL(fileURLWithPath: Paths.expand(out)), catalog: nil)
        return 0
    }

    // MARK: Output helpers

    static func colorize(_ line: String) -> String {
        if line.hasPrefix("▸") { return "\n" + cyan(bold(line)) }
        if line.hasPrefix("✓") { return green(bold(line)) }
        if line.contains("  ✓") { return line.replacingOccurrences(of: "✓", with: green("✓")) }
        if line.contains("  !") { return yellow(line) }
        if line.contains("  −") || line.contains("  ·") { return dim(line) }
        return line
    }

    static func banner() {
        print(cyan(bold("DockFolders v\(AppInfo.version)")) + dim("  macOS Dock category organizer"))
    }

    static func printHelp() {
        print("""
        \(bold("DockFolders")) v\(AppInfo.version) — macOS Dock category organizer with custom folder icons

        \(bold("USAGE"))
          dockfolders <command> [options]          (no command → opens the app)

        \(bold("COMMANDS"))
          \(green("apply"))  [--config F]   Build folders, render icons and update the Dock
          \(green("reset"))  [backup]       Restore the Dock from the latest (or given) backup
          \(green("discover"))              List installed apps that are not in any folder
          \(green("list"))                  Show folders and favorites from the config
          \(green("preset")) <name>         Replace config with a preset: \(Presets.all.map(\.id).joined(separator: ", "))
          \(green("import")) [config.sh]    Import a DockFolders v1 config.sh
          \(green("backup"))                Back up the Dock now
          \(green("backups"))               List Dock backups
          \(green("remove")) [--delete-folders]  Take the folders out of the Dock
          \(green("render-icon")) <folder|emoji> <out.png> [size]
          \(green("export")) [file.json]    Print or save the current config
          \(green("help")), \(green("version"))

        \(bold("FILES"))
          Config    \(Paths.abbreviate(Paths.configFile.path))
          Folders   \(AppSettings().foldersDirectory)
          Backups   \(AppSettings().backupDirectory)
        """)
    }
}

enum AppInfo {
    static let version = "2.0.0"
    static let bundleID = "com.geonhee15.dockfolders"
    static let repoURL = URL(string: "https://github.com/geonhee15/dockfolders")!
}
