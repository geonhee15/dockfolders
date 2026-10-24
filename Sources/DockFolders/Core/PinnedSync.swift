import Foundation

/// Keeps `DockConfig.favorites` — the Dock's left-hand app section — in step with the real Dock.
///
/// The Dock is the source of truth until the list is edited in DockFolders: apps the user drags
/// around in the Dock are adopted into the config, edits made in the app are written on Apply, and
/// `AppState.pinnedBaseline` remembers the last list both sides agreed on. When both changed, the
/// config is kept and the UI/CLI point it out so the user can pick the Dock's list instead.
enum PinnedSync {
    struct Outcome {
        /// The Dock's app section right now, as config names.
        var dock: [String] = []
        /// The config list was replaced with the Dock's.
        var adopted = false
        /// The Dock and the config both changed since the last sync; the config was kept.
        var conflict = false
    }

    /// Canonical form used for comparisons: absolute app paths plus spacer tokens.
    /// Names that resolve to nothing installed are dropped, so a missing app never counts as a change.
    static func normalize(_ names: [String], catalog: AppCatalog) -> [String] {
        names.compactMap { name in
            if PinnedToken.isSpacer(name) { return name }
            return catalog.find(name, spotlight: false)?.path
        }
    }

    static func readDock(catalog: AppCatalog) -> [String] {
        DockManager.readPinned(catalog: catalog)
    }

    /// Reconcile the config with the Dock. Call whenever the Dock may have changed (launch, app
    /// activation, before applying).
    @discardableResult
    static func reconcile(config: inout DockConfig, state: inout AppState, catalog: AppCatalog) -> Outcome {
        var out = Outcome(dock: readDock(catalog: catalog))
        let dockN = normalize(out.dock, catalog: catalog)
        let configN = normalize(config.favorites, catalog: catalog)

        // First sync, or the list is only a mirror: the Dock wins.
        guard let baseline = state.pinnedBaseline, config.settings.manageFavorites else {
            if configN != dockN { config.favorites = out.dock; out.adopted = true }
            state.pinnedBaseline = dockN
            return out
        }

        let dockChanged = dockN != baseline
        let editedHere = configN != baseline
        if dockChanged {
            if editedHere {
                out.conflict = true
            } else {
                config.favorites = out.dock
                state.pinnedBaseline = dockN
                out.adopted = true
            }
        }
        return out
    }

    /// Replace the config list with the Dock's, discarding edits made in the app.
    static func adopt(config: inout DockConfig, state: inout AppState, catalog: AppCatalog) -> [String] {
        let dock = readDock(catalog: catalog)
        config.favorites = dock
        state.pinnedBaseline = normalize(dock, catalog: catalog)
        return dock
    }

    /// After a successful apply the Dock holds exactly what the config asked for.
    static func markApplied(config: DockConfig, state: inout AppState, catalog: AppCatalog) {
        state.pinnedBaseline = normalize(config.favorites, catalog: catalog)
    }

    /// True when the config's list differs from what the Dock had at the last sync.
    static func hasPendingEdits(config: DockConfig, state: AppState, catalog: AppCatalog) -> Bool {
        guard config.settings.manageFavorites, let baseline = state.pinnedBaseline else { return false }
        return normalize(config.favorites, catalog: catalog) != baseline
    }

    /// Human-readable name for a list item (CLI and logs).
    static func describe(_ name: String) -> String {
        switch name {
        case PinnedToken.spacer: return "— spacer —"
        case PinnedToken.smallSpacer: return "– small spacer –"
        default: return name
        }
    }
}
