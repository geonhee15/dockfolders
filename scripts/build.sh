#!/bin/zsh
# ╔══════════════════════════════════════════════╗
# ║   DockFolders build script                   ║
# ║   Produces build/DockFolders.app             ║
# ╚══════════════════════════════════════════════╝
#
# Works with just the Xcode Command Line Tools (no Xcode, no SwiftPM needed).
#
#   scripts/build.sh            release build
#   scripts/build.sh --debug    fast, unoptimised build
#   UNIVERSAL=1 scripts/build.sh   arm64 + x86_64
#
set -euo pipefail

ROOT="$(cd "$(dirname "${0:A}")/.." && pwd)"
BUILD="$ROOT/build"
APP="$BUILD/DockFolders.app"
NAME="DockFolders"
VERSION="$(grep -o 'static let version = "[^"]*"' "$ROOT/Sources/DockFolders/CLI/CLI.swift" | cut -d'"' -f2)"
BUILD_NUMBER="$(date +%Y%m%d%H%M)"
MIN_MACOS="14.0"

OPT="-O"
[[ "${1:-}" == "--debug" ]] && OPT="-Onone"

GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; BLUE=$'\033[0;34m'; BOLD=$'\033[1m'; DIM=$'\033[2m'; NC=$'\033[0m'
step() { echo "\n${BLUE}${BOLD}▸${NC} ${BOLD}$*${NC}"; }

# ─── Toolchain ───
if ! command -v swiftc >/dev/null; then
  echo "swiftc not found. Install the Command Line Tools:  xcode-select --install" >&2
  exit 1
fi
SDK="$(xcrun --show-sdk-path 2>/dev/null || true)"
[[ -z "$SDK" ]] && SDK="/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk"
SDK="$(cd "$SDK" && pwd -P)"   # resolve symlink so the module cache stays consistent
TOOLCHAIN="$(cd "$(dirname "$(xcrun -f swiftc)")/../.." && pwd -P)"

EXTRA_FLAGS=()
# Work around a broken Command Line Tools install (old `usr/include/swift/module.modulemap`
# left behind next to the new `usr/include/module.modulemap` → "redefinition of module 'SwiftBridging'").
# The permanent fix is: sudo rm "$TOOLCHAIN/usr/include/swift/module.modulemap"
STALE_MAP="$TOOLCHAIN/usr/include/swift/module.modulemap"
if [[ -f "$STALE_MAP" && -f "$TOOLCHAIN/usr/include/module.modulemap" ]]; then
  mkdir -p "$BUILD/toolchain-fix"
  printf '// masked by DockFolders build (stale duplicate of SwiftBridging)\n' > "$BUILD/toolchain-fix/empty.modulemap"
  cat > "$BUILD/toolchain-fix/vfs.yaml" <<YAML
{ "version": 0, "case-sensitive": "false", "use-external-names": false,
  "roots": [ { "name": "$STALE_MAP", "type": "file", "external-contents": "$BUILD/toolchain-fix/empty.modulemap" } ] }
YAML
  EXTRA_FLAGS+=(-vfsoverlay "$BUILD/toolchain-fix/vfs.yaml" -module-cache-path "$BUILD/module-cache")
  echo "${YELLOW}⚠${NC}  Stale module map detected in Command Line Tools — applying VFS workaround."
  echo "   ${DIM}Permanent fix: sudo rm \"$STALE_MAP\"${NC}"
fi

# ─── Sources ───
SOURCES=()
while IFS= read -r f; do SOURCES+=("$f"); done < <(find "$ROOT/Sources/DockFolders" -name '*.swift' | sort)

ARCHS=("$(uname -m)")
[[ "${UNIVERSAL:-0}" == "1" ]] && ARCHS=(arm64 x86_64)

step "Compiling DockFolders v$VERSION ($OPT, ${ARCHS[*]})"
mkdir -p "$BUILD/bin"
BINARIES=()
for ARCH in "${ARCHS[@]}"; do
  OUT="$BUILD/bin/$NAME-$ARCH"
  swiftc $OPT \
    -swift-version 5 \
    -target "$ARCH-apple-macos$MIN_MACOS" \
    -sdk "$SDK" \
    "${EXTRA_FLAGS[@]}" \
    -module-name "$NAME" \
    -framework AppKit -framework SwiftUI -framework CoreText -framework CryptoKit \
    -o "$OUT" \
    "${SOURCES[@]}"
  BINARIES+=("$OUT")
  echo "  ${GREEN}✓${NC} $ARCH"
done

# ─── Bundle ───
step "Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
if [[ ${#BINARIES[@]} -gt 1 ]]; then
  lipo -create "${BINARIES[@]}" -output "$APP/Contents/MacOS/$NAME"
else
  cp "${BINARIES[1]}" "$APP/Contents/MacOS/$NAME"
fi
chmod +x "$APP/Contents/MacOS/$NAME"
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD_NUMBER/" "$ROOT/Resources/Info.plist" > "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

# App icon is rendered by the app itself (same renderer the folder icons use).
ICONSET="$BUILD/AppIcon.iconset"
rm -rf "$ICONSET"
if "$APP/Contents/MacOS/$NAME" --render-app-icon "$ICONSET" && command -v iconutil >/dev/null; then
  iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
  echo "  ${GREEN}✓${NC} AppIcon.icns"
else
  echo "  ${YELLOW}⚠${NC} could not render app icon (continuing)"
fi

# ─── Sign (ad-hoc) ───
if command -v codesign >/dev/null; then
  codesign --force --deep --sign - "$APP" 2>/dev/null && echo "  ${GREEN}✓${NC} signed (ad-hoc)"
fi

echo "\n${GREEN}${BOLD}✓ Built${NC} $APP"
echo "${DIM}  open \"$APP\"            # GUI"
echo "  \"$APP/Contents/MacOS/$NAME\" help   # CLI${NC}"
