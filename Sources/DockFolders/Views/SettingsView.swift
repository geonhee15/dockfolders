import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var confirmRemove = false
    @State private var deleteFoldersToo = true

    var body: some View {
        Form {
            Section(L("Locations")) {
                pathRow(L("Folders directory"), binding: $model.config.settings.foldersDirectory,
                        help: L("Where the symlink folders are created. The Dock points here."))
                pathRow(L("Backups directory"), binding: $model.config.settings.backupDirectory,
                        help: L("Dock snapshots are stored here before every change."))
                Stepper(value: $model.config.settings.maxBackups, in: 0...200) {
                    HStack {
                        Text(L("Keep backups"))
                        Spacer()
                        Text(model.config.settings.maxBackups == 0 ? L("all") : "\(model.config.settings.maxBackups)")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section(L("Behaviour")) {
                Toggle(L("Keep other Dock items (Downloads, etc.) next to the folders"), isOn: $model.config.settings.keepOtherDockItems)
                Toggle(L("Number folder names (01.Dev, 02.AI…)"), isOn: $model.config.settings.numberPrefix)
                Toggle(L("Restart the Dock after applying"), isOn: $model.config.settings.restartDock)
            }

            Section(L("Default Dock display for folders")) {
                DisplayPickers(display: $model.config.settings.defaultDisplay)
            }

            Section(L("Config")) {
                LabeledContent(L("Config file")) {
                    Text(Paths.abbreviate(Paths.configFile.path))
                        .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                }
                HStack {
                    Button(L("Open Config Folder")) { model.revealConfigFolder() }
                    Button(L("Export JSON…")) {
                        if let url = Panels.saveFile(title: L("Export config"), name: "dockfolders-config.json") { model.exportJSON(url: url) }
                    }
                    Button(L("Import JSON…")) {
                        if let url = Panels.chooseFile(title: L("Import config"), types: ["json"]) { model.importJSON(url: url) }
                    }
                    Button(L("Import config.sh (v1)…")) {
                        if let url = Panels.chooseFile(title: L("Choose a DockFolders v1 config.sh"), types: ["sh"]) { model.importLegacy(url: url) }
                    }
                }
            }

            Section(L("Danger zone")) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L("Remove the folders from the Dock"))
                        Text(L("Takes the DockFolders tiles out of the Dock (a backup is made first). Pinned apps are left alone."))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(L("Remove…"), role: .destructive) { confirmRemove = true }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 560)
        .frame(minHeight: 520)
        .confirmationDialog(L("Remove DockFolders from the Dock?"), isPresented: $confirmRemove) {
            Button(L("Remove tiles and delete symlink folders"), role: .destructive) { model.removeFromDock(deleteFolders: true) }
            Button(L("Remove tiles only")) { model.removeFromDock(deleteFolders: false) }
        } message: {
            Text(L("Your applications are never touched — only the symlinks DockFolders created."))
        }
    }

    private func pathRow(_ title: String, binding: Binding<String>, help: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                TextField(title, text: binding)
                    .textFieldStyle(.roundedBorder)
                Button(L("Choose…")) {
                    if let p = Panels.chooseDirectory(title: title, current: binding.wrappedValue) {
                        binding.wrappedValue = Paths.abbreviate(p)
                    }
                }
            }
            Text(help).font(.caption).foregroundStyle(.secondary)
        }
    }
}
