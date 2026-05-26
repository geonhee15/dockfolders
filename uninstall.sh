#!/bin/zsh
# DockFolders Uninstaller

set -e

GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; RED=$'\033[0;31m'
BLUE=$'\033[0;34m'; BOLD=$'\033[1m'; NC=$'\033[0m'

echo "${BLUE}${BOLD}DockFolders Uninstaller${NC}\n"

INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/dockfolders"
DOCK_FOLDERS_DIR="$HOME/Applications/DockFolders"
ICONS_DIR="$HOME/.dock_folder_icons"

echo "${YELLOW}This will remove:${NC}"
echo "  • $INSTALL_DIR/dockfolders"
echo "  • $CONFIG_DIR/"
echo "  • $DOCK_FOLDERS_DIR/"
echo "  • $ICONS_DIR/"
echo ""
echo "${YELLOW}This will NOT:${NC}"
echo "  • Restore your original Dock (run 'dockfolders reset' first if needed)"
echo "  • Uninstall dockutil, fileicon, or Pillow"
echo ""

read -q "REPLY?Continue? (y/n) "
echo ""
[[ "$REPLY" != "y" ]] && { echo "Cancelled."; exit 0; }

rm -f "$INSTALL_DIR/dockfolders"
rm -rf "$CONFIG_DIR"
rm -rf "$DOCK_FOLDERS_DIR"
rm -rf "$ICONS_DIR"

echo "\n${GREEN}✓ Uninstalled${NC}"
echo "${BLUE}Tip:${NC} To remove brew deps: brew uninstall dockutil fileicon"
