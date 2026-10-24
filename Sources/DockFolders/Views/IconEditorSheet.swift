import SwiftUI
import AppKit

/// Full icon designer: glyph (emoji / SF Symbol / image / app icon) + shape + colors.
struct IconEditorSheet: View {
    @Binding var spec: IconSpec
    let folderName: String
    let folderIndex: Int

    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var draft: IconSpec
    @State private var appSearch = ""

    init(spec: Binding<IconSpec>, folderName: String, folderIndex: Int) {
        _spec = spec
        self.folderName = folderName
        self.folderIndex = folderIndex
        _draft = State(initialValue: spec.wrappedValue)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                previewColumn
                    .frame(width: 250)
                    .padding(20)
                    .background(Color(nsColor: .windowBackgroundColor))
                Divider()
                controls
            }
            Divider()
            footer
        }
        .frame(width: 780, height: 600)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: Preview

    private var previewColumn: some View {
        VStack(spacing: 18) {
            Text(folderName).font(.headline)
            IconPreview(spec: draft, size: 168)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
            DockMock(spec: draft)
            HStack(alignment: .bottom, spacing: 16) {
                ForEach([64, 32, 16], id: \.self) { s in
                    VStack(spacing: 4) {
                        IconPreview(spec: draft, size: CGFloat(s))
                        Text("\(s)").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            Text(draft.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: Controls

    private var controls: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                group(L("Glyph")) {
                    Picker("", selection: $draft.source) {
                        Text(L("Emoji")).tag(IconSource.emoji)
                        Text(L("Symbol")).tag(IconSource.symbol)
                        Text(L("Image")).tag(IconSource.image)
                        Text(L("App Icon")).tag(IconSource.app)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    switch draft.source {
                    case .emoji: emojiControls
                    case .symbol: symbolControls
                    case .image: imageControls
                    case .app: appControls
                    }
                }

                group(L("Shape & Background")) {
                    Picker(L("Shape"), selection: $draft.shape) {
                        Text(L("Folder")).tag(IconShape.folder)
                        Text(L("Rounded")).tag(IconShape.squircle)
                        Text(L("Circle")).tag(IconShape.circle)
                        Text(L("None")).tag(IconShape.none)
                    }
                    .pickerStyle(.segmented)

                    Picker(L("Background"), selection: $draft.background) {
                        Text(L("Gradient")).tag(IconBackground.gradient)
                        Text(L("Solid")).tag(IconBackground.solid)
                        Text(L("None")).tag(IconBackground.none)
                    }
                    .pickerStyle(.segmented)
                    .disabled(draft.shape == .none)

                    HStack(spacing: 16) {
                        ColorPicker(L("Top"), selection: color($draft.color1), supportsOpacity: false)
                        ColorPicker(L("Bottom"), selection: color($draft.color2), supportsOpacity: false)
                            .disabled(draft.background != .gradient)
                        Button {
                            let p = IconPalette.random()
                            draft.color1 = RGBA(hex: p.0); draft.color2 = RGBA(hex: p.1)
                        } label: { Image(systemName: "dice") }
                            .help(L("Random colors"))
                        Button {
                            let t = draft.color1; draft.color1 = draft.color2; draft.color2 = t
                        } label: { Image(systemName: "arrow.up.arrow.down") }
                            .help(L("Swap colors"))
                    }
                    .disabled(draft.shape == .none || draft.background == .none)

                    paletteGrid
                }

                group(L("Size & Effects")) {
                    HStack {
                        Text(L("Glyph size"))
                        Slider(value: $draft.scale, in: 0.2...1.0)
                        Text("\(Int(draft.scale * 100))%")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .trailing)
                    }
                    Toggle(L("Drop shadow"), isOn: $draft.shadow)
                        .disabled(draft.shape == .none)
                }
            }
            .padding(20)
        }
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: title)
            content()
        }
    }

    private func color(_ b: Binding<RGBA>) -> Binding<Color> {
        Binding(get: { Color(nsColor: b.wrappedValue.nsColor) },
                set: { b.wrappedValue = RGBA(NSColor($0)) })
    }

    // MARK: Glyph controls

    private var emojiControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField(L("Emoji"), text: $draft.emoji)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
                    .onChange(of: draft.emoji) { _, new in
                        // Keep only the last grapheme cluster typed.
                        if new.count > 1, let last = new.last { draft.emoji = String(last) }
                    }
                Button(L("Emoji Picker…")) {
                    NSApp.orderFrontCharacterPalette(nil)
                }
                .help(L("Opens the system emoji palette (⌃⌘Space)"))
                Spacer()
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 34), spacing: 4)], spacing: 4) {
                ForEach(EmojiCatalog.common, id: \.self) { e in
                    Button {
                        draft.emoji = e
                    } label: {
                        Text(e)
                            .font(.system(size: 22))
                            .frame(width: 34, height: 34)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(draft.emoji == e ? Color.accentColor.opacity(0.25) : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var symbolControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField(L("SF Symbol name"), text: $draft.symbolName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 220)
                ColorPicker(L("Tint"), selection: color($draft.tint), supportsOpacity: false)
                Spacer()
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 36), spacing: 4)], spacing: 4) {
                ForEach(EmojiCatalog.symbols, id: \.self) { name in
                    Button {
                        draft.symbolName = name
                    } label: {
                        Image(systemName: name)
                            .font(.system(size: 17))
                            .frame(width: 36, height: 34)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(draft.symbolName == name ? Color.accentColor.opacity(0.25) : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                    .help(name)
                }
            }
        }
    }

    private var imageControls: some View {
        HStack(spacing: 12) {
            if let p = draft.imagePath, let img = NSImage(contentsOfFile: p) {
                Image(nsImage: img).resizable().aspectRatio(contentMode: .fit).frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading) {
                    Text((p as NSString).lastPathComponent).lineLimit(1)
                    Text(L("Tip: choose “None” shape and 100% size to use the image as-is."))
                        .font(.caption).foregroundStyle(.secondary)
                }
            } else {
                Image(systemName: "photo.on.rectangle").font(.largeTitle).foregroundStyle(.secondary)
                    .frame(width: 56, height: 56)
                Text(L("PNG, JPEG, ICNS, HEIC, PDF…")).foregroundStyle(.secondary)
            }
            Spacer()
            Button(L("Choose Image…")) {
                if let url = Panels.chooseImage() {
                    do { draft.imagePath = try ConfigStore.importImage(from: url) }
                    catch { model.alertMessage = error.localizedDescription }
                }
            }
            Button(L("Clear")) { draft.imagePath = nil }
                .disabled(draft.imagePath == nil)
        }
    }

    private var appControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField(L("Search installed apps"), text: $appSearch)
                .textFieldStyle(.roundedBorder)
            List(filteredApps, selection: Binding(
                get: { draft.appName.flatMap { n in model.resolve(n)?.path } },
                set: { path in draft.appName = path.flatMap { model.catalog.app(atPath: $0)?.fileName } }
            )) { app in
                HStack(spacing: 8) {
                    Image(nsImage: model.catalog.icon(forPath: app.path)).resizable().frame(width: 22, height: 22)
                    Text(app.displayName)
                }
                .tag(app.path)
            }
            .frame(height: 200)
            .border(Color(nsColor: .separatorColor))
        }
    }

    private var filteredApps: [InstalledApp] {
        let q = appSearch.lowercased().trimmed
        return q.isEmpty ? model.catalog.apps : model.catalog.apps.filter { $0.searchText.contains(q) }
    }

    private var paletteGrid: some View {
        HStack(spacing: 6) {
            ForEach(Array(IconPalette.pairs.enumerated()), id: \.offset) { _, pair in
                Button {
                    draft.color1 = RGBA(hex: pair.0); draft.color2 = RGBA(hex: pair.1)
                } label: {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(LinearGradient(colors: [Color(nsColor: RGBA(hex: pair.0).nsColor), Color(nsColor: RGBA(hex: pair.1).nsColor)], startPoint: .top, endPoint: .bottom))
                        .frame(width: 22, height: 22)
                        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.black.opacity(0.15)))
                }
                .buttonStyle(.plain)
            }
            Button {
                draft.color1 = RGBA(hex: IconPalette.systemFolder.0); draft.color2 = RGBA(hex: IconPalette.systemFolder.1)
            } label: {
                Image(systemName: "folder.fill").foregroundStyle(Color(nsColor: RGBA(hex: IconPalette.systemFolder.1).nsColor))
            }
            .buttonStyle(.plain)
            .help(L("macOS folder blue"))
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            Button(L("Reset")) {
                var fresh = IconSpec(emoji: draft.emoji, palette: folderIndex)
                fresh.source = draft.source
                fresh.symbolName = draft.symbolName
                fresh.imagePath = draft.imagePath
                fresh.appName = draft.appName
                draft = fresh
            }
            Spacer()
            Button(L("Cancel")) { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button(L("Save")) {
                spec = draft
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
        }
        .actionBar()
    }
}

/// A tiny fake Dock so the icon can be judged next to neighbours.
struct DockMock: View {
    let spec: IconSpec

    var body: some View {
        HStack(spacing: 8) {
            tile("safari", .blue)
            tile("message.fill", .green)
            Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 34)
            IconPreview(spec: spec, size: 44)
            tile("folder.fill", Color(nsColor: .systemBlue).opacity(0.8))
            tile("trash", .gray)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 14).fill(.black.opacity(0.55)))
        .background(RoundedRectangle(cornerRadius: 14).fill(.ultraThinMaterial))
    }

    private func tile(_ symbol: String, _ color: Color) -> some View {
        RoundedRectangle(cornerRadius: 9)
            .fill(color.opacity(0.9))
            .frame(width: 38, height: 38)
            .overlay(Image(systemName: symbol).foregroundStyle(.white).font(.system(size: 18)))
            .opacity(0.8)
    }
}

enum EmojiCatalog {
    static let common: [String] = [
        "📁", "📂", "🗂️", "📦", "💻", "⌨️", "🖥️", "🤖", "🧠", "🌐", "🧭", "🎨", "🖌️", "✏️", "📐", "🎬", "🎥", "📷", "🎵", "🎧", "🎤",
        "🎮", "🕹️", "🎲", "🧩", "💬", "📧", "📞", "📝", "📒", "📚", "📖", "🎓", "🔬", "🧪", "🧮", "📊", "📈", "💼", "🏢", "🏠",
        "🔧", "🛠️", "⚙️", "🧰", "🔌", "🔋", "🛡️", "🔒", "🔑", "💎", "💰", "🛒", "✈️", "🗺️", "🚀", "🛸", "⚡", "🔥", "✨", "⭐",
        "🌙", "☀️", "🌈", "🍀", "🌿", "🍎", "❤️", "🧡", "💙", "💜", "🐱", "🐶", "🦊", "🐼", "🐙", "🦄", "🏆", "🎯", "⏰", "📅",
        "🧲", "🔭", "🛰️", "🧬", "💊", "🏋️", "⚽", "🏀", "🎹", "🎸", "🥁", "🧵", "🪄", "🎁", "🧸", "📡", "🗜️", "🧊", "🪐", "🎟️",
    ]

    static let symbols: [String] = [
        "folder.fill", "hammer.fill", "terminal.fill", "chevron.left.forwardslash.chevron.right", "cpu.fill", "globe",
        "safari.fill", "paintbrush.fill", "paintpalette.fill", "camera.fill", "video.fill", "film.fill", "music.note",
        "headphones", "gamecontroller.fill", "message.fill", "bubble.left.and.bubble.right.fill", "envelope.fill",
        "doc.text.fill", "book.fill", "graduationcap.fill", "pencil.and.ruler.fill", "wrench.and.screwdriver.fill",
        "gearshape.fill", "briefcase.fill", "chart.bar.fill", "dollarsign.circle.fill", "cart.fill", "heart.fill",
        "star.fill", "bolt.fill", "flame.fill", "sparkles", "brain.head.profile", "lock.fill", "shield.fill", "cloud.fill",
        "airplane", "map.fill", "calendar", "clock.fill", "photo.fill", "puzzlepiece.fill", "lightbulb.fill", "leaf.fill",
        "pawprint.fill", "house.fill", "building.2.fill", "person.2.fill", "network", "server.rack", "externaldrive.fill",
        "printer.fill", "keyboard.fill", "display", "iphone", "tv.fill", "mic.fill", "waveform", "square.stack.3d.up.fill",
        "cube.fill", "atom", "scissors", "eyedropper", "function", "sum", "text.book.closed.fill", "newspaper.fill",
    ]
}
