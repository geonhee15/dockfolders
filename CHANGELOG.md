# Changelog

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
