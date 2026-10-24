import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Renders an `IconSpec` at a given point size, cached per spec.
struct IconPreview: View {
    let spec: IconSpec
    var size: CGFloat = 32
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Image(nsImage: IconPreviewCache.image(spec, pointSize: size, catalog: model.catalog))
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
    }
}

enum IconPreviewCache {
    private static let cache = NSCache<NSString, NSImage>()

    static func image(_ spec: IconSpec, pointSize: CGFloat, catalog: AppCatalog?) -> NSImage {
        let px = Int(pointSize * 2)
        let key = "\(spec.hashValue)-\(px)" as NSString
        if let hit = cache.object(forKey: key) { return hit }
        let img = IconRenderer.image(for: spec, pixelSize: px, catalog: catalog)
        img.size = NSSize(width: pointSize, height: pointSize)
        cache.setObject(img, forKey: key)
        return img
    }
}

/// One installed (or missing) app, by config name.
struct AppRow: View {
    @EnvironmentObject private var model: AppModel
    let name: String
    var subtitle: String? = nil

    var body: some View {
        let app = model.resolve(name)
        HStack(spacing: 10) {
            if let app {
                Image(nsImage: model.catalog.icon(forPath: app.path))
                    .resizable()
                    .frame(width: 28, height: 28)
            } else {
                Image(systemName: "questionmark.app.dashed")
                    .font(.system(size: 22))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
            }
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(app?.displayName ?? name)
                    if let app, app.displayName != app.fileName {
                        Text(app.fileName).foregroundStyle(.tertiary).font(.caption)
                    }
                }
                Text(subtitle ?? (app.map { Paths.abbreviate(($0.path as NSString).deletingLastPathComponent) } ?? L("Not installed — skipped when applying")))
                    .font(.caption)
                    .foregroundStyle(app == nil ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary))
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }
}

/// Row for an `InstalledApp` (used in pickers and discover).
struct InstalledAppRow: View {
    @EnvironmentObject private var model: AppModel
    let app: InstalledApp
    var detail: String? = nil

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: model.catalog.icon(forPath: app.path))
                .resizable()
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(app.displayName)
                    if app.displayName != app.fileName {
                        Text(app.fileName).foregroundStyle(.tertiary).font(.caption)
                    }
                }
                Text(detail ?? Paths.abbreviate((app.path as NSString).deletingLastPathComponent))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }
}

/// Small pill showing whether the Dock reflects the current config.
struct StatusBadge: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(model.hasUnappliedChanges ? Color.orange : Color.green)
                .frame(width: 8, height: 8)
            Text(model.hasUnappliedChanges ? L("Unapplied changes") : L("Dock up to date"))
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .help(model.lastAppliedDescription.map { "\(L("Last applied")): \($0)" } ?? L("Never applied"))
    }
}

struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.secondary)
            .textCase(nil)
    }
}

extension View {
    /// Standard bottom action bar.
    func actionBar() -> some View {
        self.padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)
    }
}

enum Panels {
    static func chooseDirectory(title: String, current: String?) -> String? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        if let current { panel.directoryURL = URL(fileURLWithPath: Paths.expand(current)) }
        return panel.runModal() == .OK ? panel.url?.path : nil
    }

    static func chooseFile(title: String, types: [String]) -> URL? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = types.compactMap { UTType(filenameExtension: $0) }
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func chooseImage() -> URL? {
        chooseFile(title: L("Choose an image"), types: ["png", "jpg", "jpeg", "icns", "tiff", "heic", "gif", "webp", "pdf"])
    }

    static func saveFile(title: String, name: String) -> URL? {
        let panel = NSSavePanel()
        panel.title = title
        panel.nameFieldStringValue = name
        panel.canCreateDirectories = true
        return panel.runModal() == .OK ? panel.url : nil
    }
}
