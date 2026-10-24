import Foundation
import CryptoKit

extension KeyedDecodingContainer {
    /// Decode a value, falling back to `def` when the key is missing or malformed.
    /// Keeps config files from older versions loading cleanly.
    func decode<T: Decodable>(_ key: Key, default def: T) -> T {
        (try? decodeIfPresent(T.self, forKey: key)) ?? def
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }

    /// "Visual Studio Code.app" -> "Visual Studio Code"
    var strippingAppExtension: String {
        hasSuffix(".app") ? String(dropLast(4)) : self
    }

    /// "01.Dev" -> "Dev" (legacy ordering prefix)
    var strippingNumberPrefix: String {
        guard let dot = firstIndex(of: "."), dot != startIndex else { return self }
        let head = self[startIndex..<dot]
        if head.allSatisfy(\.isNumber) { return String(self[index(after: dot)...]).trimmed }
        return self
    }

    var sha256Hex: String {
        let digest = SHA256.hash(data: Data(utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Safe single path component for a folder name on disk.
    var sanitizedFileName: String {
        var s = replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-").trimmed
        if s.hasPrefix(".") { s.removeFirst() }
        return s.isEmpty ? "Folder" : s
    }
}

extension Array where Element: Hashable {
    /// Remove duplicates, keeping first occurrence order.
    var uniqued: [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

extension DateFormatter {
    static let backupStamp: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd_HHmmss"
        return f
    }()
}
