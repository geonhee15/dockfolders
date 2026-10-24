import SwiftUI

/// The Dock's left-hand app section.
struct FavoritesView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selected = Set<String>()
    @State private var showPicker = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "star.fill").foregroundStyle(.yellow).font(.title)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L("Favorites")).font(.title.weight(.semibold))
                        Text(L("Apps that stay pinned on the left side of the Dock, before the folders."))
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                Toggle(L("Replace the Dock's app section with this list when applying"), isOn: $model.config.settings.manageFavorites)
                HStack(spacing: 16) {
                    Toggle(L("Spacer after favorites"), isOn: $model.config.settings.useSpacer)
                    Toggle(L("Small spacer"), isOn: $model.config.settings.smallSpacer)
                        .disabled(!model.config.settings.useSpacer)
                }
                .disabled(!model.config.settings.manageFavorites)
            }
            .padding(20)
            Divider()
            if model.config.favorites.isEmpty {
                ContentUnavailableView {
                    Label(L("No favorites"), systemImage: "star")
                } description: {
                    Text(model.config.settings.manageFavorites
                         ? L("Applying with an empty list clears the Dock's app section (the folders remain).")
                         : L("The Dock's app section is left untouched."))
                } actions: {
                    Button(L("Add Favorites…")) { showPicker = true }.buttonStyle(.borderedProminent)
                }
            } else {
                List(selection: $selected) {
                    ForEach(model.config.favorites, id: \.self) { name in
                        AppRow(name: name)
                            .tag(name)
                            .contextMenu {
                                Button(L("Remove from Favorites")) { model.removeFavorites([name]) }
                            }
                    }
                    .onMove { model.moveFavorites(from: $0, to: $1) }
                }
                .onDeleteCommand { model.removeFavorites(selected); selected = [] }
                .dropDestination(for: URL.self) { urls, _ in
                    model.addFavorites(urls.compactMap { model.catalog.app(atPath: $0.path)?.fileName })
                    return true
                }
                .opacity(model.config.settings.manageFavorites ? 1 : 0.5)
            }
            Divider()
            HStack(spacing: 10) {
                Button { showPicker = true } label: { Label(L("Add Favorites…"), systemImage: "plus") }
                Button { model.removeFavorites(selected); selected = [] } label: { Image(systemName: "minus") }
                    .disabled(selected.isEmpty)
                Spacer()
                Text("\(model.config.favorites.count) \(L("apps")) · \(L("drag to reorder"))")
                    .font(.callout).foregroundStyle(.secondary)
            }
            .actionBar()
        }
        .navigationTitle(L("Favorites"))
        .sheet(isPresented: $showPicker) { AppPickerSheet(mode: .favorites) }
    }
}
