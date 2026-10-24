import Foundation

/// An application bundle found on this Mac.
struct InstalledApp: Identifiable, Hashable {
    var id: String { path }
    /// Absolute path of the .app bundle.
    let path: String
    /// Bundle file name without ".app" — the canonical name stored in the config.
    let fileName: String
    /// Localized name as Finder shows it (may equal `fileName`).
    let displayName: String
    let bundleID: String?

    var name: String { fileName }

    /// Case-insensitive match against file name, display name, bundle id or path.
    func matches(_ query: String) -> Bool {
        let raw = query.trimmed
        if raw.isEmpty { return false }
        if raw.hasPrefix("/") || raw.hasPrefix("~") {
            let p = Paths.expand(raw)
            return p == path || p + ".app" == path
        }
        let q = raw.strippingAppExtension
        if fileName.caseInsensitiveCompare(q) == .orderedSame { return true }
        if displayName.caseInsensitiveCompare(q) == .orderedSame { return true }
        if let b = bundleID, b.caseInsensitiveCompare(q) == .orderedSame { return true }
        return false
    }

    var searchText: String {
        [fileName, displayName, bundleID ?? ""].joined(separator: " ").lowercased()
    }
}
