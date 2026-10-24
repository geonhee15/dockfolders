#!/bin/zsh
# ╔══════════════════════════════════════════════╗
# ║   DockFolders Installer                      ║
# ╚══════════════════════════════════════════════╝
#
# Quick install from this directory:
#   ./install.sh
#
# Or from anywhere:
#   curl -fsSL https://raw.githubusercontent.com/Geonhee15/dockfolders/main/install.sh | zsh

set -e

GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; RED=$'\033[0;31m'
BLUE=$'\033[0;34m'; BOLD=$'\033[1m'; NC=$'\033[0m'

echo "${BLUE}${BOLD}"
echo "╔═══════════════════════════════════════════╗"
echo "║   📁 Installing DockFolders               ║"
echo "╚═══════════════════════════════════════════╝${NC}"

SCRIPT_DIR="$(cd "$(dirname "${0:A}")" && pwd)"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/dockfolders"

# ─── Check macOS ───
if [[ "$(uname)" != "Darwin" ]]; then
    echo "${RED}✗ macOS only${NC}"
    exit 1
fi

# ─── Check Homebrew ───
if ! command -v brew &>/dev/null; then
    echo "${YELLOW}Homebrew not found. Install from https://brew.sh${NC}"
    echo "Run:"
    echo '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    exit 1
fi

# ─── Install dependencies ───
echo "\n${BLUE}▸${NC} Installing dependencies..."
for tool in dockutil fileicon; do
    if ! command -v "$tool" &>/dev/null; then
        echo "  Installing $tool..."
        brew install "$tool"
    else
        echo "  ${GREEN}✓${NC} $tool already installed"
    fi
done

# ─── Optional: Pillow for emoji rendering ───
if ! python3 -c "from PIL import Image" 2>/dev/null; then
    echo "  Installing Pillow (for emoji icons)..."
    python3 -m pip install --user --break-system-packages pillow 2>&1 | tail -2 || true
fi

# ─── Install dockfolders script ───
echo "\n${BLUE}▸${NC} Installing dockfolders to $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR"
cp "$SCRIPT_DIR/dockfolders" "$INSTALL_DIR/dockfolders"
chmod +x "$INSTALL_DIR/dockfolders"
echo "  ${GREEN}✓${NC} Installed: $INSTALL_DIR/dockfolders"

# Also copy presets directory if it exists
if [[ -d "$SCRIPT_DIR/presets" ]]; then
    mkdir -p "$INSTALL_DIR/../share/dockfolders/presets"
    cp -r "$SCRIPT_DIR/presets"/*.sh "$INSTALL_DIR/../share/dockfolders/presets/" 2>/dev/null || true
fi

# ─── Setup default config ───
if [[ ! -f "$CONFIG_DIR/config.sh" ]]; then
    echo "\n${BLUE}▸${NC} Creating default config..."
    mkdir -p "$CONFIG_DIR"
    cp "$SCRIPT_DIR/config.example.sh" "$CONFIG_DIR/config.sh"
    echo "  ${GREEN}✓${NC} Config: $CONFIG_DIR/config.sh"
fi

# ─── Add to PATH if needed ───
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo "\n${YELLOW}⚠${NC}  $INSTALL_DIR not in PATH"
    echo "  Add this to your ~/.zshrc:"
    echo "    ${BOLD}export PATH=\"\$HOME/.local/bin:\$PATH\"${NC}"
fi

# ─── Done ───
echo "\n${GREEN}${BOLD}╔═══════════════════════════════════════════╗${NC}"
echo "${GREEN}${BOLD}║   ✨ Installation complete!               ║${NC}"
echo "${GREEN}${BOLD}╚═══════════════════════════════════════════╝${NC}"

echo "\n${BLUE}Next steps:${NC}"
echo "  1. Edit config:  ${BOLD}\$EDITOR $CONFIG_DIR/config.sh${NC}"
echo "  2. Run:          ${BOLD}dockfolders organize${NC}"
echo "  3. Help:         ${BOLD}dockfolders help${NC}"
