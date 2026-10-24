# Changelog

## 2.1.0 — 2026-10-24

### Changed
- **Pinned apps follow the Dock.** The left-hand section of the Dock is no longer overwritten on every apply. DockFolders reads what is pinned, adopts changes made by dragging apps in the Dock itself, and writes the list back only when it was edited in the app. If both changed, the app says so and offers the Dock's list.
- "Favorites" is now "Pinned Apps" in the UI and CLI output; the JSON key stays `favorites`.
- Presets no longer replace the pinned apps unless that section of the Dock is empty.

### Added
- Spacers are items of the pinned list (`"<spacer>"`, `"<small-spacer>"`): add, move and remove them like apps. The old `useSpacer`/`smallSpacer` settings are migrated automatically.
- `dockfolders pinned` shows the Dock's pinned apps next to the config's; `dockfolders pinned --from-dock` adopts the Dock's.
- "Reload from Dock" in the Pinned Apps view.

### Fixed
- Apps that are symlinks in /Applications (Safari on recent macOS, Homebrew casks) are found by the catalog and no longer reported as "not installed" or dropped from the Dock.
- Dock tiles that cannot be resolved to an installed app are kept instead of removed.
- Existing Dock tiles are reused when the pinned section is rewritten, so the Dock keeps its bookkeeping for apps that merely moved.

## 2.0.0 — 2026-10-24

Complete rewrite as a native macOS app (SwiftUI + AppKit), no external dependencies.

### Added
- **GUI**: sidebar of folders, per-folder app management (add/remove/move, drag & drop from Finder), favorites, uncategorized-app finder, backup browser, settings.
- **Icon editor**: emoji, SF Symbol, custom image or app icon as the glyph; folder / rounded / circle / none shapes; gradient or solid backgrounds with a palette; size slider; shadow; live preview at Dock sizes.
- **Native rendering**: icons are drawn with CoreGraphics (16–1024 px) and applied with `NSWorkspace` — Pillow and fileicon are no longer needed.
- **Native Dock writing**: folder and favorite tiles are written to `com.apple.dock` directly — dockutil is no longer needed.
- **Presets** (developer, creator, student, minimal) with colors, and an onboarding sheet on first launch.
- **Backups** before every change, with in-app restore and retention limit.
- **Unapplied-changes badge** in the toolbar.
- **Per-folder Dock display options** (view, display as, sort).
- **CLI** built into the app binary: `apply`, `reset`, `discover`, `list`, `preset`, `import`, `backup(s)`, `remove`, `render-icon`, `export`.
- **Korean localization** (follows the system language).
- `scripts/build.sh` builds the `.app` with only the Command Line Tools and works around a stale-module-map CLT install.

### Changed
- Config moved from `config.sh` to JSON (`~/.config/dockfolders/config.json`); v1 configs are imported automatically.
- Dock backups live in `~/.config/dockfolders/backups` instead of the Desktop.
- Folder names no longer need the `01.` ordering prefix (optional setting).
- Other Dock items (Downloads…) are kept by default instead of being wiped.

### Legacy
- The v1 zsh implementation moved to `legacy/`.
