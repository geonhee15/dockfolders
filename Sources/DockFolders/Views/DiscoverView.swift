import SwiftUI

/// Installed apps that are in no folder and not a favorite.
struct DiscoverView: View {
    @EnvironmentObject private var model: AppModel
    @State private var search = ""

    private var filtered: [InstalledApp] {
        let q = search.lowercased().trimmed
        return q.isEmpty ? model.uncategorized : model.uncategorized.filter { $0.searchText.contains(q) }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "tray.full").foregroundStyle(.blue).font(.title)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L("Uncategorized")).font(.title.weight(.semibold))
                        Text("\(model.uncategorized.count) \(L("of")) \(model.catalog.apps.count) \(L("installed apps are not in any folder."))")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if model.isScanning { ProgressView().controlSize(.small) }
                }
                TextField(L("Search"), text: $search).textFieldStyle(.roundedBorder)
            }
            .padding(20)
            Divider()
            if filtered.isEmpty {
                ContentUnavailableView {
                    Label(search.isEmpty ? L("Everything is organized") : L("No matching apps"), systemImage: "checkmark.seal")
                }
            } else {
                List(filtered) { app in
                    HStack {
                        InstalledAppRow(app: app)
                        Menu {
                            ForEach(model.config.folders) { folder in
                                Button {
                                    model.addApps([app.fileName], to: folder.id)
                                } label: {
                                    Label(folder.name, systemImage: "folder")
                                }
                            }
                            if !model.config.folders.isEmpty { Divider() }
                            Button(L("Favorites")) { model.addFavorites([app.fileName]) }
                            Button(L("New Folder with This App")) { model.newFolder(withApp: app) }
                            Divider()
                            Button(L("Reveal in Finder")) { model.reveal(app: app) }
                        } label: {
                            Label(L("Add to"), systemImage: "plus.circle")
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                    }
                    .draggable(URL(fileURLWithPath: app.path))
                }
            }
            Divider()
            HStack {
                Text(L("Tip: drag an app onto a folder in the sidebar."))
                    .font(.callout).foregroundStyle(.secondary)
                Spacer()
                Button { model.rescan() } label: { Label(L("Rescan"), systemImage: "arrow.clockwise") }
                    .disabled(model.isScanning)
            }
            .actionBar()
        }
        .navigationTitle(L("Uncategorized"))
    }
}
