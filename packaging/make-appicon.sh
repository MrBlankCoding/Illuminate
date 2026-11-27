#!/usr/bin/env bash
#
# Regenerates packaging/icons/AppIcon.icns from packaging/icons/illuminate.svg.
# Run this after editing the SVG; the resulting .icns is checked in so that a
# plain ./build.sh --package never needs a Qt-capable toolchain for icons.
#
# Usage:
#   packaging/make-appicon.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SVG="$SCRIPT_DIR/icons/illuminate.svg"
ICNS="$SCRIPT_DIR/icons/AppIcon.icns"
WORK_DIR="${TMPDIR:-/tmp}/illuminate-appicon.$$"
ICONSET="$WORK_DIR/AppIcon.iconset"

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "✗ AppIcon.icns is macOS-only; nothing to do on $(uname -s)."
    exit 0
fi
command -v iconutil >/dev/null 2>&1 || {
    echo "✗ iconutil not found; it ships with macOS."
    exit 1
}
[[ -f "$SVG" ]] || { echo "✗ Missing source icon: $SVG"; exit 1; }

# mirror build.sh's Qt discovery: an explicit QT_DIR wins, else the CMake config
QT_PREFIX="${QT_DIR:-$(command -v qmake6 >/dev/null 2>&1 && qmake6 -query QT_INSTALL_PREFIX || true)}"

cleanup() { rm -rf "$WORK_DIR"; }
trap cleanup EXIT
mkdir -p "$ICONSET"

echo "→ Rendering SVG to iconset…"
if [[ -n "$QT_PREFIX" ]]; then
    cmake -S "$SCRIPT_DIR/icongen" -B "$WORK_DIR/build" \
          -DCMAKE_PREFIX_PATH="$QT_PREFIX" >/dev/null
else
    cmake -S "$SCRIPT_DIR/icongen" -B "$WORK_DIR/build" >/dev/null
fi
cmake --build "$WORK_DIR/build" --parallel "$(sysctl -n hw.logicalcpu)" >/dev/null

# offscreen: there is no display, and the renderer only needs QGuiApplication
QT_QPA_PLATFORM=offscreen "$WORK_DIR/build/icongen" "$SVG" "$ICONSET"

echo "→ Assembling AppIcon.icns…"
iconutil -c icns "$ICONSET" -o "$ICNS"

echo "✓ Wrote $ICNS"
