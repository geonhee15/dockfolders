import Foundation
import AppKit

/// sRGB color stored as 0...1 components; serialized as "#RRGGBB[AA]".
struct RGBA: Hashable {
    var r: Double
    var g: Double
    var b: Double
    var a: Double

    init(r: Double, g: Double, b: Double, a: Double = 1) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }

    init(hex: String) {
        var s = hex.trimmed
        if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0
        guard (s.count == 6 || s.count == 8), Scanner(string: s).scanHexInt64(&v) else {
            self = RGBA(r: 0.23, g: 0.48, b: 1, a: 1); return
        }
        if s.count == 6 { v = (v << 8) | 0xFF }
        r = Double((v >> 24) & 0xFF) / 255
        g = Double((v >> 16) & 0xFF) / 255
        b = Double((v >> 8) & 0xFF) / 255
        a = Double(v & 0xFF) / 255
    }

    init(_ color: NSColor) {
        let c = color.usingColorSpace(.sRGB) ?? color
        r = Double(c.redComponent); g = Double(c.greenComponent)
        b = Double(c.blueComponent); a = Double(c.alphaComponent)
    }

    var hex: String {
        func h(_ x: Double) -> String { String(format: "%02X", Int((min(max(x, 0), 1) * 255).rounded())) }
        return a >= 0.999 ? "#\(h(r))\(h(g))\(h(b))" : "#\(h(r))\(h(g))\(h(b))\(h(a))"
    }

    var nsColor: NSColor { NSColor(srgbRed: r, green: g, blue: b, alpha: a) }
    var cgColor: CGColor { nsColor.cgColor }

    static let white = RGBA(r: 1, g: 1, b: 1)
    static let black = RGBA(r: 0, g: 0, b: 0)
}

extension RGBA: Codable {
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        self.init(hex: try c.decode(String.self))
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(hex)
    }
}

enum IconSource: String, Codable, CaseIterable, Identifiable {
    case emoji, symbol, image, app
    var id: String { rawValue }
}

enum IconShape: String, Codable, CaseIterable, Identifiable {
    case folder, squircle, circle, none
    var id: String { rawValue }
}

enum IconBackground: String, Codable, CaseIterable, Identifiable {
    case gradient, solid, none
    var id: String { rawValue }
}

/// Everything needed to render a folder icon. Rendered natively (no Python / fileicon).
struct IconSpec: Hashable, Codable {
    var source: IconSource = .emoji
    var emoji: String = "📁"
    var symbolName: String = "folder.fill"
    /// Absolute path of a user supplied image (copied into the config folder).
    var imagePath: String? = nil
    /// Name of an installed app whose icon is used as the glyph.
    var appName: String? = nil

    var shape: IconShape = .folder
    var background: IconBackground = .gradient
    var color1: RGBA = RGBA(hex: "#3A7BFF")
    var color2: RGBA = RGBA(hex: "#6C4DFF")
    /// Tint for SF Symbols.
    var tint: RGBA = .white
    /// Glyph size as a fraction of the canvas (0.2 ... 1.0).
    var scale: Double = 0.58
    var shadow: Bool = true

    init() {}

    init(emoji: String, palette index: Int) {
        self.emoji = emoji
        let pair = IconPalette.pairs[((index % IconPalette.pairs.count) + IconPalette.pairs.count) % IconPalette.pairs.count]
        color1 = RGBA(hex: pair.0)
        color2 = RGBA(hex: pair.1)
    }

    enum CodingKeys: String, CodingKey {
        case source, emoji, symbolName, imagePath, appName, shape, background, color1, color2, tint, scale, shadow
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = IconSpec()
        source = c.decode(.source, default: d.source)
        emoji = c.decode(.emoji, default: d.emoji)
        symbolName = c.decode(.symbolName, default: d.symbolName)
        imagePath = c.decode(.imagePath, default: d.imagePath)
        appName = c.decode(.appName, default: d.appName)
        shape = c.decode(.shape, default: d.shape)
        background = c.decode(.background, default: d.background)
        color1 = c.decode(.color1, default: d.color1)
        color2 = c.decode(.color2, default: d.color2)
        tint = c.decode(.tint, default: d.tint)
        scale = min(max(c.decode(.scale, default: d.scale), 0.2), 1.0)
        shadow = c.decode(.shadow, default: d.shadow)
    }

    /// Short human readable description, e.g. "💻 · folder · gradient".
    var summary: String {
        let glyph: String
        switch source {
        case .emoji: glyph = emoji
        case .symbol: glyph = symbolName
        case .image: glyph = imagePath.map { ($0 as NSString).lastPathComponent } ?? "image"
        case .app: glyph = appName ?? "app"
        }
        return "\(glyph) · \(shape.rawValue) · \(background.rawValue)"
    }
}

/// Curated gradient pairs used to auto-color new folders.
enum IconPalette {
    static let pairs: [(String, String)] = [
        ("#3A7BFF", "#6C4DFF"), // blue → violet
        ("#FF6B6B", "#FF9F43"), // coral → orange
        ("#2ED573", "#1E90FF"), // green → blue
        ("#FF4D8D", "#FF8E53"), // pink → peach
        ("#7B61FF", "#C850C0"), // violet → magenta
        ("#00C2FF", "#0066FF"), // cyan → blue
        ("#F7B733", "#FC4A1A"), // amber → red
        ("#43E97B", "#38F9D7"), // green → teal
        ("#FA709A", "#FEE140"), // rose → yellow
        ("#30CFD0", "#330867"), // teal → indigo
        ("#5F72BE", "#9921E8"), // steel → purple
        ("#4FACFE", "#00F2FE"), // sky → aqua
        ("#F093FB", "#F5576C"), // lilac → red
        ("#5EE7DF", "#B490CA"), // mint → lavender
        ("#1F3B73", "#4A6FBF"), // navy → blue
        ("#8E9EAB", "#EEF2F3"), // gray → silver
    ]

    /// Classic macOS folder blue (for people who want the system look).
    static let systemFolder = ("#6FB7FF", "#3E8EF7")

    static func random() -> (String, String) { pairs.randomElement() ?? pairs[0] }
}
