import SwiftUI

enum PickerMode: Equatable {
    case folder(UUID)
    case favorites
}

/// Searchable multi-select list of installed apps.
struct AppPickerSheet: View {
    let mode: PickerMode

    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var selected = Set<String>()   // app paths
    @State private var hideCategorized = false

    private var alreadyIn: Set<String> {
        switch mode {
        case .folder(let id):
            return Set((model.config.folder(id)?.apps ?? []).compactMap { model.resolve($0)?.path })
        case .favorites:
            return Set(model.config.favorites.compactMap { model.resolve($0)?.path })
        }
    }

    private var title: String {
        switch mode {
        case .folder(let id): return "\(L("Add apps to")) “\(model.config.folder(id)?.name ?? "")”"
        case .favorites: return L("Add favorites")
        }
    }

    private var filtered: [InstalledApp] {
        let q = search.lowercased().trimmed
        let uncategorized = Set(model.uncategorized.map(\.path))
        return model.catalog.apps.filter { app in
            if alreadyIn.contains(app.path) { return false }
            if hideCategorized && !uncategorized.contains(app.path) { return false }
            return q.isEmpty || app.searchText.contains(q)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text(title).font(.headline)
                HStack {
                    TextField(L("Search"), text: $search)
                        .textFieldStyle(.roundedBorder)
                    Toggle(L("Only uncategorized"), isOn: $hideCategorized)
                        .toggleStyle(.checkbox)
                }
            }
            .padding(16)
            Divider()
            List {
                ForEach(filtered) { app in
                    Toggle(isOn: Binding(
                        get: { selected.contains(app.path) },
                        set: { on in if on { selected.insert(app.path) } else { selected.remove(app.path) } }
                    )) {
                        InstalledAppRow(app: app, detail: locationText(for: app))
                    }
                    .toggleStyle(.checkbox)
                }
                if filtered.isEmpty {
                    Text(model.isScanning ? L("Scanning applications…") : L("No matching apps"))
                        .foregroundStyle(.secondary)
                }
            }
            Divider()
            HStack {
                Text("\(selected.count) \(L("selected"))")
                    .foregroundStyle(.secondary)
                Spacer()
                Button(L("Cancel")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(L("Add")) { commit() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(selected.isEmpty)
            }
            .actionBar()
        }
        .frame(width: 540, height: 580)
    }

    private func locationText(for app: InstalledApp) -> String {
        let folders = model.config.folders.filter { f in f.apps.contains { model.resolve($0)?.path == app.path } }
        if !folders.isEmpty { return "\(L("In")): " + folders.map(\.name).joined(separator: ", ") }
        if model.config.favorites.contains(where: { model.resolve($0)?.path == app.path }) { return L("In favorites") }
        return Paths.abbreviate((app.path as NSString).deletingLastPathComponent)
    }

    private func commit() {
        let names = model.catalog.apps.filter { selected.contains($0.path) }.map(\.fileName)
        switch mode {
        case .folder(let id): model.addApps(names, to: id)
        case .favorites: model.addFavorites(names)
        }
        dismiss()
    }
}
