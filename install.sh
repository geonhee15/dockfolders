#!/bin/zsh
# ╔══════════════════════════════════════════════╗
# ║   DockFolders Installer (v2, native app)     ║
# ╚══════════════════════════════════════════════╝
#
#   git clone https://github.com/geonhee15/dockfolders.git
#   cd dockfolders && ./install.sh
#
# Builds DockFolders.app with the Xcode Command Line Tools (no Xcode, no Homebrew needed),
# installs it to /Applications and adds a `dockfolders` command to ~/.local/bin.
#
#   APP_DEST=~/Applications ./install.sh    install somewhere else
#   BIN_DIR=/usr/local/bin ./install.sh     put the CLI somewhere else
set -euo pipefail

GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; RED=$'\033[0;31m'; BLUE=$'\033[0;34m'; BOLD=$'\033[1m'; DIM=$'\033[2m'; NC=$'\033[0m'
echo "${BLUE}${BOLD}"
echo "╔═══════════════════════════════════════════╗"
echo "║   📁 Installing DockFolders               ║"
echo "╚═══════════════════════════════════════════╝${NC}"

SCRIPT_DIR="$(cd "$(dirname "${0:A}")" && pwd)"
APP_NAME="DockFolders.app"
APP_DEST="${APP_DEST:-/Applications}"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/dockfolders"

[[ "$(uname)" != "Darwin" ]] && { echo "${RED}✗ macOS only${NC}"; exit 1; }

if ! xcode-select -p >/dev/null 2>&1 || ! command -v swiftc >/dev/null; then
  echo "${YELLOW}⚠${NC}  The Xcode Command Line Tools are required to build the app."
  echo "   Run:  ${BOLD}xcode-select --install${NC}   then re-run this installer."
  exit 1
fi

# ─── Build ───
echo "\n${BLUE}▸${NC} Building (this takes a minute the first time)…"
"$SCRIPT_DIR/scripts/build.sh" | sed -e 's/^/  /'

# ─── Install app ───
if [[ ! -w "$APP_DEST" ]]; then
  echo "${YELLOW}⚠${NC}  $APP_DEST is not writable, installing to ~/Applications instead"
  APP_DEST="$HOME/Applications"
fi
mkdir -p "$APP_DEST"
echo "\n${BLUE}▸${NC} Installing to $APP_DEST/$APP_NAME"
pkill -x DockFolders 2>/dev/null || true
rm -rf "$APP_DEST/$APP_NAME"
ditto "$SCRIPT_DIR/build/$APP_NAME" "$APP_DEST/$APP_NAME"
echo "  ${GREEN}✓${NC} $APP_DEST/$APP_NAME"

# ─── CLI wrapper ───
mkdir -p "$BIN_DIR"
cat > "$BIN_DIR/dockfolders" <<WRAP
#!/bin/zsh
# DockFolders CLI — forwards to the app bundle. No arguments opens the GUI.
APP="$APP_DEST/$APP_NAME"
if [[ ! -x "\$APP/Contents/MacOS/DockFolders" ]]; then
  echo "DockFolders.app not found at \$APP — re-run install.sh" >&2; exit 1
fi
if [[ \$# -eq 0 ]]; then
  exec open -a "\$APP"
fi
exec "\$APP/Contents/MacOS/DockFolders" "\$@"
WRAP
chmod +x "$BIN_DIR/dockfolders"
echo "  ${GREEN}✓${NC} $BIN_DIR/dockfolders"

# ─── Migrate a v1 config ───
if [[ -f "$CONFIG_DIR/config.sh" && ! -f "$CONFIG_DIR/config.json" ]]; then
  echo "\n${BLUE}▸${NC} Importing your v1 config.sh…"
  "$APP_DEST/$APP_NAME/Contents/MacOS/DockFolders" import "$CONFIG_DIR/config.sh" | sed -e 's/^/  /'
fi

# ─── PATH hint ───
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
  echo "\n${YELLOW}⚠${NC}  $BIN_DIR is not in your PATH. Add to ~/.zshrc:"
  echo "    ${BOLD}export PATH=\"$BIN_DIR:\$PATH\"${NC}"
fi

echo "\n${GREEN}${BOLD}╔═══════════════════════════════════════════╗${NC}"
echo "${GREEN}${BOLD}║   ✨ Installation complete!               ║${NC}"
echo "${GREEN}${BOLD}╚═══════════════════════════════════════════╝${NC}"
echo "\n${BLUE}Next:${NC}"
echo "  • Open the app:   ${BOLD}open -a DockFolders${NC}   (or from Launchpad / Spotlight)"
echo "  • Or use the CLI: ${BOLD}dockfolders preset developer && dockfolders apply${NC}"
echo "  • Help:           ${BOLD}dockfolders help${NC}"
