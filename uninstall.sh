#!/bin/zsh
# DockFolders Uninstaller (v2)
set -e

GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; BLUE=$'\033[0;34m'; BOLD=$'\033[1m'; NC=$'\033[0m'
echo "${BLUE}${BOLD}DockFolders Uninstaller${NC}\n"

BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/dockfolders"
APP=""
for candidate in "/Applications/DockFolders.app" "$HOME/Applications/DockFolders.app"; do
  [[ -d "$candidate" ]] && APP="$candidate" && break
done

echo "${YELLOW}This will remove:${NC}"
[[ -n "$APP" ]] && echo "  • $APP"
echo "  • $BIN_DIR/dockfolders"
echo ""
echo "${YELLOW}Optional (asked below):${NC}"
echo "  • Take the folders out of the Dock and delete the symlink folders"
echo "  • $CONFIG_DIR (config, backups, custom icon images)"
echo ""

read -q "REPLY?Continue? (y/n) "; echo ""
[[ "$REPLY" != "y" ]] && { echo "Cancelled."; exit 0; }

if [[ -n "$APP" ]]; then
  read -q "REPLY?Remove the folders from the Dock first? (y/n) "; echo ""
  if [[ "$REPLY" == "y" ]]; then
    "$APP/Contents/MacOS/DockFolders" remove --delete-folders || true
  fi
fi

pkill -x DockFolders 2>/dev/null || true
[[ -n "$APP" ]] && rm -rf "$APP"
rm -f "$BIN_DIR/dockfolders"

read -q "REPLY?Delete config and backups in $CONFIG_DIR? (y/n) "; echo ""
[[ "$REPLY" == "y" ]] && rm -rf "$CONFIG_DIR"

echo "\n${GREEN}✓ Uninstalled${NC}"
