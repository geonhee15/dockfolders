import Foundation
import AppKit
import CoreText

/// Renders `IconSpec`s to bitmaps and applies them to folders — no Python, no fileicon.
enum IconRenderer {
    static let repSizes = [16, 32, 64, 128, 256, 512, 1024]

    // MARK: Public API

    /// Multi-representation image suitable for `NSWorkspace.setIcon`.
    static func iconImage(for spec: IconSpec, catalog: AppCatalog?) -> NSImage {
        let image = NSImage(size: NSSize(width: 1024, height: 1024))
        for s in repSizes {
            if let rep = bitmap(spec, pixelSize: s, catalog: catalog) {
                image.addRepresentation(rep)
            }
        }
        return image
    }

    /// Single bitmap of the given pixel size (previews, PNG export).
    static func image(for spec: IconSpec, pixelSize: Int, catalog: AppCatalog?) -> NSImage {
        let image = NSImage(size: NSSize(width: pixelSize, height: pixelSize))
        if let rep = bitmap(spec, pixelSize: pixelSize, catalog: catalog) {
            image.addRepresentation(rep)
        }
        return image
    }

    @discardableResult
    static func apply(_ spec: IconSpec, toFolder path: String, catalog: AppCatalog?) -> Bool {
        guard FileManager.default.fileExists(atPath: path) else { return false }
        let image = iconImage(for: spec, catalog: catalog)
        return NSWorkspace.shared.setIcon(image, forFile: path, options: [])
    }

    static func removeIcon(fromFolder path: String) {
        guard FileManager.default.fileExists(atPath: path) else { return }
        NSWorkspace.shared.setIcon(nil, forFile: path, options: [])
    }

    static func writePNG(_ spec: IconSpec, pixelSize: Int, to url: URL, catalog: AppCatalog?) throws {
        guard let rep = bitmap(spec, pixelSize: pixelSize, catalog: catalog),
              let data = rep.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "DockFolders", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not render icon"])
        }
        try data.write(to: url)
    }

    /// Writes an `.iconset` folder (used at build time for the app's own icon).
    static func writeIconset(_ spec: IconSpec, to dir: URL, catalog: AppCatalog?) throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for base in [16, 32, 128, 256, 512] {
            try writePNG(spec, pixelSize: base, to: dir.appendingPathComponent("icon_\(base)x\(base).png"), catalog: catalog)
            try writePNG(spec, pixelSize: base * 2, to: dir.appendingPathComponent("icon_\(base)x\(base)@2x.png"), catalog: catalog)
        }
    }

    // MARK: Bitmap

    static func bitmap(_ spec: IconSpec, pixelSize: Int, catalog: AppCatalog?) -> NSBitmapImageRep? {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: pixelSize, pixelsHigh: pixelSize,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { return nil }
        rep.size = NSSize(width: pixelSize, height: pixelSize)
        guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = ctx
        ctx.imageInterpolation = .high
        let cg = ctx.cgContext
        cg.clear(CGRect(x: 0, y: 0, width: pixelSize, height: pixelSize))
        draw(spec, size: CGFloat(pixelSize), in: cg, catalog: catalog)
        ctx.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()
        return rep
    }

    // MARK: Drawing

    static func draw(_ spec: IconSpec, size S: CGFloat, in cg: CGContext, catalog: AppCatalog?) {
        cg.saveGState()
        cg.setAllowsAntialiasing(true)
        cg.setShouldAntialias(true)
        cg.interpolationQuality = .high

        let shapePath = path(for: spec.shape, size: S)
        if let shapePath, spec.background != .none {
            // Shadow + base fill
            cg.saveGState()
            if spec.shadow {
                cg.setShadow(offset: CGSize(width: 0, height: -S * 0.02), blur: S * 0.05,
                             color: CGColor(gray: 0, alpha: 0.35))
            }
            cg.addPath(shapePath)
            cg.setFillColor(spec.color1.cgColor)
            cg.fillPath()
            cg.restoreGState()

            if spec.background == .gradient {
                cg.saveGState()
                cg.addPath(shapePath)
                cg.clip()
                let space = CGColorSpaceCreateDeviceRGB()
                if let gradient = CGGradient(colorsSpace: space,
                                             colors: [spec.color1.cgColor, spec.color2.cgColor] as CFArray,
                                             locations: [0, 1]) {
                    cg.drawLinearGradient(gradient, start: CGPoint(x: S / 2, y: S), end: CGPoint(x: S / 2, y: 0), options: [])
                }
                cg.restoreGState()
            }

            // Shape-specific detailing
            switch spec.shape {
            case .folder:
                cg.saveGState()
                cg.addPath(folderFrontPath(size: S))
                cg.setFillColor(CGColor(gray: 1, alpha: 0.16))
                cg.fillPath()
                cg.restoreGState()
            case .squircle, .circle:
                // subtle top highlight
                cg.saveGState()
                cg.addPath(shapePath)
                cg.clip()
                let space = CGColorSpaceCreateDeviceRGB()
                if let g = CGGradient(colorsSpace: space,
                                      colors: [CGColor(gray: 1, alpha: 0.18), CGColor(gray: 1, alpha: 0)] as CFArray,
                                      locations: [0, 1]) {
                    cg.drawLinearGradient(g, start: CGPoint(x: S / 2, y: S), end: CGPoint(x: S / 2, y: S * 0.45), options: [])
                }
                cg.restoreGState()
            case .none:
                break
            }
        }

        let frame = glyphFrame(for: spec, size: S)
        drawGlyph(spec, in: frame, size: S, cg: cg, catalog: catalog)
        cg.restoreGState()
    }

    static func path(for shape: IconShape, size S: CGFloat) -> CGPath? {
        switch shape {
        case .none:
            return nil
        case .squircle:
            let inset = S * 0.08
            return CGPath(roundedRect: CGRect(x: inset, y: inset, width: S - inset * 2, height: S - inset * 2),
                          cornerWidth: S * 0.21, cornerHeight: S * 0.21, transform: nil)
        case .circle:
            let inset = S * 0.08
            return CGPath(ellipseIn: CGRect(x: inset, y: inset, width: S - inset * 2, height: S - inset * 2), transform: nil)
        case .folder:
            let p = CGMutablePath()
            p.addPath(CGPath(roundedRect: CGRect(x: S * 0.08, y: S * 0.68, width: S * 0.40, height: S * 0.19),
                             cornerWidth: S * 0.06, cornerHeight: S * 0.06, transform: nil))
            p.addPath(CGPath(roundedRect: CGRect(x: S * 0.05, y: S * 0.13, width: S * 0.90, height: S * 0.66),
                             cornerWidth: S * 0.09, cornerHeight: S * 0.09, transform: nil))
            return p
        }
    }

    /// Lighter "front flap" of the folder shape.
    static func folderFrontPath(size S: CGFloat) -> CGPath {
        CGPath(roundedRect: CGRect(x: S * 0.05, y: S * 0.13, width: S * 0.90, height: S * 0.55),
               cornerWidth: S * 0.09, cornerHeight: S * 0.09, transform: nil)
    }

    static func glyphFrame(for spec: IconSpec, size S: CGFloat) -> CGRect {
        let scale = CGFloat(min(max(spec.scale, 0.2), 1.0))
        switch spec.shape {
        case .none:
            let side = S * scale
            return CGRect(x: (S - side) / 2, y: (S - side) / 2, width: side, height: side)
        case .squircle, .circle:
            let side = S * scale * 0.95
            return CGRect(x: (S - side) / 2, y: (S - side) / 2, width: side, height: side)
        case .folder:
            let side = S * scale * 0.85
            let cy = S * 0.405
            return CGRect(x: (S - side) / 2, y: cy - side / 2, width: side, height: side)
        }
    }

    static func drawGlyph(_ spec: IconSpec, in frame: CGRect, size S: CGFloat, cg: CGContext, catalog: AppCatalog?) {
        switch spec.source {
        case .emoji:
            drawEmoji(spec.emoji.isEmpty ? "📁" : spec.emoji, in: frame, cg: cg)
        case .symbol:
            drawSymbol(spec.symbolName, tint: spec.tint, in: frame, cg: cg)
        case .image:
            if let p = spec.imagePath, let img = NSImage(contentsOfFile: p) {
                drawImage(img, in: frame)
            } else {
                drawSymbol("photo", tint: spec.tint, in: frame, cg: cg)
            }
        case .app:
            if let name = spec.appName, let app = catalog?.find(name, spotlight: false) {
                drawImage(NSWorkspace.shared.icon(forFile: app.path), in: frame)
            } else {
                drawSymbol("app.dashed", tint: spec.tint, in: frame, cg: cg)
            }
        }
    }

    static func drawEmoji(_ emoji: String, in frame: CGRect, cg: CGContext) {
        func line(_ fontSize: CGFloat) -> (CTLine, CGRect) {
            let attr = NSAttributedString(string: emoji, attributes: [.font: NSFont.systemFont(ofSize: fontSize)])
            let l = CTLineCreateWithAttributedString(attr)
            return (l, CTLineGetImageBounds(l, cg))
        }
        var (ctLine, bounds) = line(frame.height)
        let maxSide = max(bounds.width, bounds.height)
        if maxSide > 1 {
            let factor = frame.height / maxSide
            (ctLine, bounds) = line(frame.height * factor)
        }
        guard bounds.width > 0, bounds.height > 0 else { return }
        cg.saveGState()
        cg.textMatrix = .identity
        cg.textPosition = CGPoint(x: frame.midX - bounds.midX, y: frame.midY - bounds.midY)
        CTLineDraw(ctLine, cg)
        cg.restoreGState()
    }

    static func drawSymbol(_ name: String, tint: RGBA, in frame: CGRect, cg: CGContext) {
        let config = NSImage.SymbolConfiguration(pointSize: frame.height * 0.8, weight: .medium)
        guard let symbol = (NSImage(systemSymbolName: name, accessibilityDescription: nil)
                            ?? NSImage(systemSymbolName: "folder.fill", accessibilityDescription: nil))?
                .withSymbolConfiguration(config) else { return }
        let rect = aspectFit(symbol.size, in: frame)
        // Draw the template as a mask, then fill with the tint inside a transparency layer
        // so the background underneath is preserved.
        cg.saveGState()
        cg.beginTransparencyLayer(auxiliaryInfo: nil)
        symbol.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        cg.setBlendMode(.sourceIn)
        cg.setFillColor(tint.cgColor)
        cg.fill(rect.insetBy(dx: -2, dy: -2))
        cg.endTransparencyLayer()
        cg.restoreGState()
    }

    static func drawImage(_ image: NSImage, in frame: CGRect) {
        let size = image.size.width > 0 ? image.size : NSSize(width: 1, height: 1)
        let rect = aspectFit(size, in: frame)
        image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true,
                   hints: [.interpolation: NSImageInterpolation.high])
    }

    static func aspectFit(_ size: NSSize, in frame: CGRect) -> CGRect {
        guard size.width > 0, size.height > 0 else { return frame }
        let scale = min(frame.width / size.width, frame.height / size.height)
        let w = size.width * scale, h = size.height * scale
        return CGRect(x: frame.midX - w / 2, y: frame.midY - h / 2, width: w, height: h)
    }

    // MARK: App icon (build time)

    /// The DockFolders application icon: indigo squircle with a white folder glyph.
    static var appIconSpec: IconSpec {
        var s = IconSpec()
        s.source = .symbol
        s.symbolName = "folder.fill"
        s.shape = .squircle
        s.background = .gradient
        s.color1 = RGBA(hex: "#5B8CFF")
        s.color2 = RGBA(hex: "#5E3BEE")
        s.tint = .white
        s.scale = 0.62
        s.shadow = false
        return s
    }
}
