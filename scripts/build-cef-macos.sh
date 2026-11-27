#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
WORK_DIR="${CEF_BUILD_DIR:-$HOME/cef-build-illuminate}"
CEF_INSTALL_DIR="${CEF_INSTALL_DIR:-$HOME/cef}"
PYTHON="${PYTHON:-python3}"
DEPOT_TOOLS="$WORK_DIR/depot_tools"
SOURCE_DIR="$WORK_DIR/src"

for tool in curl git python3 cmake ninja; do
    command -v "$tool" >/dev/null || { echo "Missing required tool: $tool" >&2; exit 1; }
done
[[ "$(uname -s)" == Darwin ]] || { echo "This script builds macOS CEF only." >&2; exit 1; }
[[ "$(uname -m)" == arm64 || "$(uname -m)" == x86_64 ]] || { echo "Unsupported macOS architecture." >&2; exit 1; }
[[ "$(xcodebuild -version | sed -n '1s/.* //p')" == 27.* ]] || {
    echo "Latest CEF macOS branch requires Xcode 27.0 or newer." >&2
    exit 1
}

mkdir -p "$WORK_DIR" "$CEF_INSTALL_DIR"
INDEX="$WORK_DIR/cef-index.json"
curl -fsSL https://cef-builds.spotifycdn.com/index.json -o "$INDEX"

read -r CEF_VERSION CEF_BRANCH < <("$PYTHON" - "$INDEX" "$(uname -m)" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
platform = 'macosarm64' if sys.argv[2] == 'arm64' else 'macosx64'
versions = [v for v in data[platform]['versions'] if v.get('channel') == 'stable']
def key(v):
    return tuple(int(part) for part in v['cef_version'].split('+', 1)[0].split('.'))
latest = max(versions, key=key)
print(latest['cef_version'], latest['chromium_version'].split('.')[2])
PY
)
[[ -n "$CEF_VERSION" && -n "$CEF_BRANCH" ]] || { echo "Could not select latest stable CEF." >&2; exit 1; }

echo "→ Building CEF $CEF_VERSION (branch $CEF_BRANCH) with H.264/AAC support"
if [[ ! -d "$DEPOT_TOOLS/.git" ]]; then
    git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git "$DEPOT_TOOLS"
fi
if [[ ! -f "$WORK_DIR/automate-git.py" ]]; then
    curl -fsSL https://raw.githubusercontent.com/chromiumembedded/cef/master/tools/automate/automate-git.py \
        -o "$WORK_DIR/automate-git.py"
fi

export DEPOT_TOOLS_DIR="$DEPOT_TOOLS"
export DEPOT_TOOLS_BOOTSTRAP_PYTHON3=0
export DEPOT_TOOLS_UPDATE=0
export PATH="$DEPOT_TOOLS:$PATH"
export GN_DEFINES="is_official_build=true proprietary_codecs=true ffmpeg_branding=Chrome"

ARCH_FLAG="--arm64-build"
[[ "$(uname -m)" == arm64 ]] || ARCH_FLAG="--x64-build"

python3 "$WORK_DIR/automate-git.py" \
    --download-dir="$SOURCE_DIR" \
    --depot-tools-dir="$DEPOT_TOOLS" \
    --branch="$CEF_BRANCH" \
    "$ARCH_FLAG" \
    --no-debug-build \
    --no-debug-tests \
    --no-distrib-docs \
    --no-distrib-archive

CEF_ROOT="$(find "$SOURCE_DIR/chromium/src/cef/binary_distrib" -maxdepth 1 -type d -name "cef_binary_${CEF_VERSION}_macos*" -print -quit)"
[[ -n "$CEF_ROOT" && -d "$CEF_ROOT" ]] || { echo "CEF distribution output not found." >&2; exit 1; }

INSTALLED_CEF="$CEF_INSTALL_DIR/$CEF_VERSION-illuminate-$(uname -m)"
[[ ! -e "$INSTALLED_CEF" ]] || { echo "Refusing to overwrite $INSTALLED_CEF" >&2; exit 1; }
cp -R "$CEF_ROOT" "$INSTALLED_CEF"

echo "→ Building Illuminate against $INSTALLED_CEF"
CEF_ROOT="$INSTALLED_CEF" "$ROOT/build.sh" --package
echo "✓ CEF: $INSTALLED_CEF"
echo "✓ Illuminate package: $ROOT/dist"
