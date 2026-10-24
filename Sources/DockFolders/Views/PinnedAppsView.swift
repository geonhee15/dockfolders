import SwiftUI

/// The Dock's left-hand app section. The list follows the Dock (see `PinnedSync`); edits made
/// here are written on Apply.
struct PinnedAppsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selected = Set<Int>()
    @State private var showPicker = false
    @State private var confirmAdopt = false

    private var items: [String] { model.config.favorites }
    private var manage: Bool { model.config.settings.manageFavorites }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(20)
            Divider()
            if items.isEmpty { emptyState } else { list }
            Divider()
            bottomBar
        }
        .navigationTitle(L("Pinned Apps"))
        .sheet(isPresented: $showPicker) { AppPickerSheet(mode: .favorites) }
        .confirmationDialog(L("Replace this list with the Dock's pinned apps?"), isPresented: $confirmAdopt) {
            Button(L("Use the Dock's List"), role: .destructive) { model.adoptPinnedFromDock(); selected = [] }
        } message: {
            Text(L("Edits you made here that haven't been applied are discarded."))
        }
        .onAppear { model.syncPinned() }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "pin.fill").foregroundStyle(.orange).font(.title)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("Pinned Apps")).font(.title.weight(.semibold))
                    Text(L("The apps on the left side of the Dock. This list follows the Dock — rearrange apps there or here, then apply."))
                        .font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
            }
            Toggle(L("Write this list to the Dock when applying"), isOn: $model.config.settings.manageFavorites)
            status
        }
    }

    @ViewBuilder
    private var status: some View {
        if !manage {
            Label(L("Off — the Dock's pinned apps are left as they are; this list only mirrors them."), systemImage: "eye")
                .font(.callout).foregroundStyle(.secondary)
        } else if model.pinnedConflict {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Label(L("The Dock's pinned apps changed outside DockFolders, and this list has unapplied edits. Applying keeps this list."),
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.callout).foregroundStyle(.orange)
                Spacer(minLength: 0)
                Button(L("Use the Dock's List…")) { confirmAdopt = true }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.12)))
        } else if model.pinnedPending {
            Label(L("Edited here — apply to update the Dock."), systemImage: "pencil.circle")
                .font(.callout).foregroundStyle(.orange)
        } else {
            Label(L("In sync with the Dock."), systemImage: "checkmark.circle")
                .font(.callout).foregroundStyle(.green)
        }
    }

    // MARK: List

    private var list: some View {
        List(selection: $selected) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                row(item)
                    .tag(index)
                    .contextMenu {
                        if PinnedToken.isSpacer(item) {
                            Button(item == PinnedToken.spacer ? L("Make Small") : L("Make Regular")) { model.toggleSpacerSize(at: index) }
                        } else if let app = model.resolve(item) {
                            Button(L("Reveal in Finder")) { model.reveal(app: app) }
                        }
                        Divider()
                        Button(L("Remove"), role: .destructive) { model.removePinned(at: IndexSet(integer: index)); selected = [] }
                    }
            }
            .onMove { from, to in
                model.moveFavorites(from: from, to: to)
                selected = []
            }
        }
        .onDeleteCommand { model.removePinned(at: IndexSet(selected)); selected = [] }
        .dropDestination(for: URL.self) { urls, _ in
            model.addFavorites(urls.compactMap { model.catalog.app(atPath: $0.path)?.fileName })
            return true
        }
        .disabled(!manage)
        .opacity(manage ? 1 : 0.6)
    }

    @ViewBuilder
    private func row(_ item: String) -> some View {
        if PinnedToken.isSpacer(item) {
            let small = item == PinnedToken.smallSpacer
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .foregroundStyle(.tertiary)
                    .frame(width: small ? 14 : 28, height: 28)
                    .frame(width: 28)
                Text(small ? L("Small spacer") : L("Spacer")).foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 2)
        } else {
            AppRow(name: item)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(L("No pinned apps"), systemImage: "pin")
        } description: {
            Text(manage
                 ? L("The Dock's app section is empty. Add apps here and apply, or drag them into the Dock.")
                 : L("The Dock's app section is left untouched."))
        } actions: {
            Button(L("Add Apps…")) { showPicker = true }
                .buttonStyle(.borderedProminent)
                .disabled(!manage)
        }
    }

    // MARK: Bottom bar

    private var bottomBar: some View {
        HStack(spacing: 10) {
            Button { showPicker = true } label: { Label(L("Add Apps…"), systemImage: "plus") }
            Menu {
                Button(L("Spacer")) { model.addSpacer(small: false) }
                Button(L("Small spacer")) { model.addSpacer(small: true) }
            } label: {
                Label(L("Add Spacer"), systemImage: "rectangle.split.3x1")
            }
            .fixedSize()
            Button { model.removePinned(at: IndexSet(selected)); selected = [] } label: { Image(systemName: "minus") }
                .disabled(selected.isEmpty)
            Spacer()
            Button {
                if model.pinnedPending || model.pinnedConflict { confirmAdopt = true } else { model.adoptPinnedFromDock() }
            } label: {
                Label(L("Reload from Dock"), systemImage: "arrow.triangle.2.circlepath")
            }
            .help(L("Replace this list with what the Dock currently shows"))
            Text("\(model.config.pinnedAppNames.count) \(L("apps")) · \(L("drag to reorder"))")
                .font(.callout).foregroundStyle(.secondary)
        }
        .actionBar()
        .disabled(!manage)
    }
}
