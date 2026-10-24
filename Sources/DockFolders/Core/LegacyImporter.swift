import Foundation

/// Imports a v1 `config.sh` (zsh arrays) into a `DockConfig`.
///
/// Recognised keys: CATEGORIES ("Name|Emoji|App1,App2"), FAVORITES, DOCK_FOLDERS_DIR, BACKUP_DIR, USE_SPACER.
enum LegacyImporter {
    struct ImportError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    static func importConfig(at url: URL, into existing: AppSettings = AppSettings()) throws -> DockConfig {
        let text: String
        do { text = try String(contentsOf: url, encoding: .utf8) } catch {
            throw ImportError(message: "Could not read \(url.path): \(error.localizedDescription)")
        }
        return try parse(text, settings: existing)
    }

    static func parse(_ text: String, settings existing: AppSettings = AppSettings()) throws -> DockConfig {
        let categories = arrayValues(named: "CATEGORIES", in: text)
        if categories.isEmpty {
            throw ImportError(message: "No CATEGORIES=( ... ) block found. Is this a DockFolders v1 config.sh?")
        }
        var favorites = arrayValues(named: "FAVORITES", in: text)

        var folders: [DockFolder] = []
        for (i, entry) in categories.enumerated() {
            let parts = entry.components(separatedBy: "|")
            guard parts.count >= 2 else { continue }
            let rawName = parts[0].trimmed
            let emoji = parts[1].trimmed
            let apps = parts.count >= 3
                ? parts[2].components(separatedBy: ",").map(\.trimmed).filter { !$0.isEmpty }
                : []
            let name = rawName.strippingNumberPrefix
            var icon = IconSpec(emoji: emoji.isEmpty ? "📁" : emoji, palette: i)
            if emoji.isEmpty { icon.source = .symbol }
            folders.append(DockFolder(name: name, icon: icon, apps: apps))
        }

        var settings = existing
        if let dir = scalarValue(named: "DOCK_FOLDERS_DIR", in: text) {
            settings.foldersDirectory = Paths.abbreviate(Paths.expand(dir))
        }
        let useSpacer = scalarValue(named: "USE_SPACER", in: text).map { $0.lowercased() != "false" } ?? true
        if useSpacer, !favorites.isEmpty { favorites.append(PinnedToken.spacer) }
        // v1 wrote backups to the Desktop; keep the new tidy default unless the user customised it.
        if let backup = scalarValue(named: "BACKUP_DIR", in: text), !backup.contains("Desktop") {
            settings.backupDirectory = Paths.abbreviate(Paths.expand(backup))
        }
        settings.manageFavorites = !favorites.isEmpty
        return DockConfig(folders: folders, favorites: favorites, settings: settings)
    }

    /// Collects the double-quoted strings inside `NAME=( ... )`.
    private static func arrayValues(named name: String, in text: String) -> [String] {
        guard let range = text.range(of: "\(name)=(") else { return [] }
        let after = text[range.upperBound...]
        guard let close = after.range(of: ")") else { return [] }
        let body = String(after[..<close.lowerBound])
        var out: [String] = []
        var inQuote = false
        var current = ""
        var quoteChar: Character = "\""
        for ch in body {
            if inQuote {
                if ch == quoteChar { inQuote = false; out.append(current); current = "" }
                else { current.append(ch) }
            } else if ch == "\"" || ch == "'" {
                inQuote = true; quoteChar = ch
            }
        }
        return out.map(\.trimmed).filter { !$0.isEmpty }
    }

    /// `NAME="value"` or `NAME=value` (first match wins, comments ignored).
    private static func scalarValue(named name: String, in text: String) -> String? {
        for line in text.components(separatedBy: .newlines) {
            let t = line.trimmed
            guard !t.hasPrefix("#"), t.hasPrefix("\(name)=") else { continue }
            var v = String(t.dropFirst(name.count + 1)).trimmed
            if let hash = v.range(of: " #") { v = String(v[..<hash.lowerBound]).trimmed }
            v = v.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            return v
        }
        return nil
    }
}
