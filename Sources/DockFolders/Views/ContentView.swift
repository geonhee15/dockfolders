import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 210, ideal: 240, max: 320)
        } detail: {
            DetailView()
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Menu {
                    Button(L("New Folder")) { model.addFolder() }
                    Menu(L("Add Preset Folders")) {
                        ForEach(Presets.all) { p in
                            Button("\(p.emoji) \(p.name)") { model.loadPreset(p, replace: false) }
                        }
                    }
                    Divider()
                    Button(L("Import config.sh (v1)…")) {
                        if let url = Panels.chooseFile(title: L("Choose a DockFolders v1 config.sh"), types: ["sh"]) {
                            model.importLegacy(url: url)
                        }
                    }
                } label: {
                    Label(L("Add"), systemImage: "plus")
                }
                .help(L("Add a folder"))
            }
            ToolbarItemGroup(placement: .primaryAction) {
                StatusBadge()
                Button {
                    model.rescan()
                } label: {
                    if model.isScanning {
                        ProgressView().controlSize(.small)
                    } else {
                        Label(L("Rescan Apps"), systemImage: "arrow.clockwise")
                    }
                }
                .help(L("Rescan installed applications"))
                .disabled(model.isScanning)
                Button {
                    model.apply()
                } label: {
                    Label(L("Apply to Dock"), systemImage: "dock.rectangle")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("r", modifiers: .command)
                .disabled(model.progress.isRunning || model.config.folders.isEmpty || model.catalogVersion == 0)
                .help(L("Create the folders, render icons and update the Dock (⌘R)"))
            }
        }
        .sheet(isPresented: $model.showProgressSheet) { ProgressSheet() }
        .sheet(isPresented: $model.showOnboarding) { OnboardingSheet() }
        .alert(L("DockFolders"), isPresented: Binding(get: { model.alertMessage != nil }, set: { if !$0 { model.alertMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.alertMessage ?? "")
        }
        .frame(minWidth: 900, minHeight: 560)
    }
}

struct DetailView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        switch model.selection {
        case .folder(let id):
            if model.config.folder(id) != nil {
                FolderDetailView(folderID: id).id(id)
            } else {
                placeholder
            }
        case .favorites: PinnedAppsView()
        case .discover: DiscoverView()
        case .backups: BackupsView()
        case nil: placeholder
        }
    }

    private var placeholder: some View {
        ContentUnavailableView {
            Label(L("No folder selected"), systemImage: "folder")
        } description: {
            Text(L("Pick a folder in the sidebar, or create a new one with the + button."))
        } actions: {
            Button(L("New Folder")) { model.addFolder() }
        }
    }
}

struct SidebarView: View {
    @EnvironmentObject private var model: AppModel
    @State private var folderToDelete: DockFolder?

    var body: some View {
        List(selection: $model.selection) {
            Section(L("Folders")) {
                ForEach(model.config.folders) { folder in
                    FolderRow(folder: folder)
                        .tag(SidebarItem.folder(folder.id))
                        .contextMenu {
                            Button(L("Duplicate")) { model.duplicateFolder(folder.id) }
                            Button(L("Reveal in Finder")) { revealFolder(folder) }
                            Divider()
                            Button(L("Delete…"), role: .destructive) { folderToDelete = folder }
                        }
                        .dropDestination(for: URL.self) { urls, _ in
                            model.addApps(urls.map(\.path), to: folder.id)
                            return true
                        }
                }
                .onMove { model.moveFolders(from: $0, to: $1) }
                if model.config.folders.isEmpty {
                    Text(L("No folders yet")).foregroundStyle(.secondary)
                }
            }
            Section(L("Dock")) {
                Label(L("Pinned Apps"), systemImage: "pin")
                    .tag(SidebarItem.favorites)
                    .badge(model.config.pinnedAppNames.count)
                Label(L("Uncategorized"), systemImage: "tray")
                    .tag(SidebarItem.discover)
                    .badge(model.uncategorized.count)
                Label(L("Backups"), systemImage: "clock.arrow.circlepath")
                    .tag(SidebarItem.backups)
                    .badge(model.backups.count)
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button {
                    model.addFolder()
                } label: {
                    Label(L("New Folder"), systemImage: "plus.circle")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.bar)
        }
        .confirmationDialog(
            L("Delete this folder?"),
            isPresented: Binding(get: { folderToDelete != nil }, set: { if !$0 { folderToDelete = nil } }),
            presenting: folderToDelete
        ) { folder in
            Button(L("Delete") + " “\(folder.name)”", role: .destructive) { model.deleteFolder(folder.id) }
        } message: { folder in
            Text(L("The folder disappears from the Dock the next time you apply. Your apps are not touched."))
        }
    }

    private func revealFolder(_ folder: DockFolder) {
        let path = model.config.diskPath(for: folder)
        if FileManager.default.fileExists(atPath: path) {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
        } else {
            model.alertMessage = L("The folders haven't been created yet. Apply to Dock first.")
        }
    }
}

struct FolderRow: View {
    @EnvironmentObject private var model: AppModel
    let folder: DockFolder

    var body: some View {
        HStack(spacing: 9) {
            IconPreview(spec: folder.icon, size: 26)
            Text(folder.name).lineLimit(1)
            Spacer()
            Text("\(folder.apps.count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}
