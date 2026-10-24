import SwiftUI

/// Dock preference backups taken before every apply.
struct BackupsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var toRestore: URL?

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short; return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "clock.arrow.circlepath").foregroundStyle(.purple).font(.title)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L("Backups")).font(.title.weight(.semibold))
                        Text(L("A snapshot of the Dock is saved before every change. Restore one to undo."))
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                Text(Paths.abbreviate(model.config.settings.backupDirectoryExpanded))
                    .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
            }
            .padding(20)
            Divider()
            if model.backups.isEmpty {
                ContentUnavailableView {
                    Label(L("No backups yet"), systemImage: "clock")
                } description: {
                    Text(L("The first backup is created when you apply to the Dock."))
                } actions: {
                    Button(L("Back Up Now")) { model.backupNow() }
                }
            } else {
                List(model.backups, id: \.self) { url in
                    HStack(spacing: 12) {
                        Image(systemName: "doc.badge.clock").font(.title2).foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(DockManager.backupDate(url).map { Self.dateFormatter.string(from: $0) } ?? url.lastPathComponent)
                            Text(url.lastPathComponent).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(L("Restore…")) { toRestore = url }
                        Button { model.deleteBackup(url) } label: { Image(systemName: "trash") }
                            .help(L("Delete backup"))
                    }
                    .padding(.vertical, 2)
                }
            }
            Divider()
            HStack {
                Button { model.backupNow() } label: { Label(L("Back Up Now"), systemImage: "plus") }
                Button(L("Reveal in Finder")) {
                    let dir = model.config.settings.backupDirectoryExpanded
                    if FileManager.default.fileExists(atPath: dir) { NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: dir) }
                }
                Spacer()
                Text("\(model.backups.count) \(L("backups"))").font(.callout).foregroundStyle(.secondary)
            }
            .actionBar()
        }
        .navigationTitle(L("Backups"))
        .onAppear { model.refreshBackups() }
        .confirmationDialog(
            L("Restore this Dock backup?"),
            isPresented: Binding(get: { toRestore != nil }, set: { if !$0 { toRestore = nil } }),
            presenting: toRestore
        ) { url in
            Button(L("Restore and Restart Dock")) { model.restore(url) }
        } message: { url in
            Text("\(L("The Dock will be reset to")) \(DockManager.backupDate(url).map { Self.dateFormatter.string(from: $0) } ?? url.lastPathComponent).")
        }
    }
}
