import SwiftUI

struct FolderDetailView: View {
    @EnvironmentObject private var model: AppModel
    let folderID: UUID

    @State private var selectedApps = Set<String>()
    @State private var showIconEditor = false
    @State private var showAppPicker = false
    @State private var showDisplayOptions = false
    @State private var confirmDelete = false

    private var folder: DockFolder { model.config.folder(folderID) ?? DockFolder(name: "", icon: IconSpec()) }
    private var folderIndex: Int { model.config.index(of: folderID) ?? 0 }
    private var missingCount: Int { folder.apps.filter { model.resolve($0) == nil }.count }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if folder.apps.isEmpty { emptyState } else { appList }
            Divider()
            bottomBar
        }
        .navigationTitle(folder.name)
        .sheet(isPresented: $showIconEditor) {
            IconEditorSheet(spec: model.folderBinding(folderID).icon, folderName: folder.name, folderIndex: folderIndex)
        }
        .sheet(isPresented: $showAppPicker) {
            AppPickerSheet(mode: .folder(folderID))
        }
        .confirmationDialog(L("Delete this folder?"), isPresented: $confirmDelete) {
            Button(L("Delete") + " “\(folder.name)”", role: .destructive) { model.deleteFolder(folderID) }
        } message: {
            Text(L("The folder disappears from the Dock the next time you apply. Your apps are not touched."))
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top, spacing: 18) {
            Button { showIconEditor = true } label: {
                IconPreview(spec: folder.icon, size: 96)
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, Color.accentColor)
                            .offset(x: 4, y: 4)
                    }
            }
            .buttonStyle(.plain)
            .help(L("Edit icon"))

            VStack(alignment: .leading, spacing: 6) {
                TextField(L("Folder name"), text: model.folderBinding(folderID).name)
                    .font(.title.weight(.semibold))
                    .textFieldStyle(.plain)
                Text(Paths.abbreviate(model.config.diskPath(for: folder)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                HStack(spacing: 8) {
                    Button { showIconEditor = true } label: { Label(L("Edit Icon…"), systemImage: "paintbrush") }
                    Button { showDisplayOptions.toggle() } label: { Label(L("Dock Display…"), systemImage: "rectangle.3.group") }
                        .popover(isPresented: $showDisplayOptions, arrowEdge: .bottom) {
                            DisplayOptionsView(folderID: folderID)
                        }
                    Spacer()
                }
                .padding(.top, 4)
            }
            Spacer()
            Menu {
                Button(L("Duplicate")) { model.duplicateFolder(folderID) }
                Button(L("Reveal in Finder")) { reveal() }
                Divider()
                Button(L("Delete…"), role: .destructive) { confirmDelete = true }
            } label: {
                Image(systemName: "ellipsis.circle").font(.title2)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .padding(20)
    }

    // MARK: Apps

    private var appList: some View {
        List(selection: $selectedApps) {
            Section {
                ForEach(folder.apps, id: \.self) { name in
                    AppRow(name: name)
                        .tag(name)
                        .contextMenu {
                            Button(L("Remove from Folder")) { model.removeApps([name], from: folderID) }
                            Menu(L("Move to")) {
                                ForEach(model.config.folders.filter { $0.id != folderID }) { other in
                                    Button(other.name) { model.moveApp(name, from: folderID, to: other.id) }
                                }
                            }
                            if let app = model.resolve(name) {
                                Divider()
                                Button(L("Reveal in Finder")) { model.reveal(app: app) }
                            }
                        }
                }
            } header: {
                Text(L("Apps in this folder"))
            }
        }
        .onDeleteCommand {
            model.removeApps(selectedApps, from: folderID)
            selectedApps = []
        }
        .dropDestination(for: URL.self) { urls, _ in
            model.addApps(urls.map(\.path), to: folderID)
            return true
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(L("No apps yet"), systemImage: "app.dashed")
        } description: {
            Text(L("Add apps with the button below, or drag apps here from the Finder or the Uncategorized list."))
        } actions: {
            Button(L("Add Apps…")) { showAppPicker = true }
                .buttonStyle(.borderedProminent)
        }
        .dropDestination(for: URL.self) { urls, _ in
            model.addApps(urls.map(\.path), to: folderID)
            return true
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 10) {
            Button { showAppPicker = true } label: { Label(L("Add Apps…"), systemImage: "plus") }
                .keyboardShortcut("a", modifiers: [.command, .shift])
            Button {
                model.removeApps(selectedApps, from: folderID)
                selectedApps = []
            } label: { Image(systemName: "minus") }
                .disabled(selectedApps.isEmpty)
                .help(L("Remove selected apps"))
            Spacer()
            Text(summaryText)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .actionBar()
    }

    private var summaryText: String {
        var s = "\(folder.apps.count) \(L("apps"))"
        if missingCount > 0 { s += " · \(missingCount) \(L("not installed"))" }
        return s
    }

    private func reveal() {
        let path = model.config.diskPath(for: folder)
        if FileManager.default.fileExists(atPath: path) {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
        } else {
            model.alertMessage = L("The folders haven't been created yet. Apply to Dock first.")
        }
    }
}

/// Per-folder override of how the Dock shows the tile.
struct DisplayOptionsView: View {
    @EnvironmentObject private var model: AppModel
    let folderID: UUID

    private var binding: Binding<DockFolder> { model.folderBinding(folderID) }
    private var custom: Binding<Bool> {
        Binding(
            get: { binding.wrappedValue.display != nil },
            set: { on in binding.wrappedValue.display = on ? model.config.settings.defaultDisplay : nil }
        )
    }
    private var display: Binding<FolderDisplay> {
        Binding(
            get: { binding.wrappedValue.display ?? model.config.settings.defaultDisplay },
            set: { binding.wrappedValue.display = $0 }
        )
    }

    var body: some View {
        Form {
            Toggle(L("Custom display for this folder"), isOn: custom)
            DisplayPickers(display: display)
                .disabled(!custom.wrappedValue)
            Text(L("Defaults live in Settings."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 320)
    }
}

struct DisplayPickers: View {
    @Binding var display: FolderDisplay

    var body: some View {
        Picker(L("View content as"), selection: $display.showAs) {
            Text(L("Automatic")).tag(DockShowAs.auto)
            Text(L("Fan")).tag(DockShowAs.fan)
            Text(L("Grid")).tag(DockShowAs.grid)
            Text(L("List")).tag(DockShowAs.list)
        }
        Picker(L("Display as"), selection: $display.displayAs) {
            Text(L("Folder")).tag(DockDisplayAs.folder)
            Text(L("Stack")).tag(DockDisplayAs.stack)
        }
        Picker(L("Sort by"), selection: $display.arrangement) {
            Text(L("Name")).tag(DockArrangement.name)
            Text(L("Date Added")).tag(DockArrangement.dateAdded)
            Text(L("Date Modified")).tag(DockArrangement.dateModified)
            Text(L("Date Created")).tag(DockArrangement.dateCreated)
            Text(L("Kind")).tag(DockArrangement.kind)
        }
    }
}
