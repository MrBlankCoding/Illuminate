#!/usr/bin/env bash
#
# install-cef.sh — Download and install the Chromium Embedded Framework (CEF)
# binary distribution for macOS, Linux and Windows.
#
# Usage:
#   ./install-cef.sh                     # detect platform, install latest stable
#   ./install-cef.sh --version 130.0.15  # install a specific CEF version
#
# After installation, CEF_ROOT will be printed so you can export it or pass
# it to cmake -DCMAKE_PREFIX_PATH=<path>.
#
set -euo pipefail

CEF_INDEX="https://cef-builds.spotifycdn.com/index.json"
INSTALL_DIR="${CEF_INSTALL_DIR:-$HOME/cef}"

# ── helpers ────────────────────────────────────────────────────────────────────

require_cmd() {
    if ! command -v "$1" &>/dev/null; then
        echo "✗ Required command not found: $1" >&2
        exit 1
    fi
}

detect_platform() {
    local os arch
    os="$(uname -s)"
    arch="$(uname -m)"

    case "$os" in
        Darwin)
            case "$arch" in
                arm64) echo "macosarm64" ;;
                x86_64) echo "macosx64" ;;
                *)
                    echo "Unsupported macOS arch: $arch" >&2
                    exit 1
                    ;;
            esac
            ;;
        Linux)
            case "$arch" in
                x86_64) echo "linux64" ;;
                aarch64) echo "linuxarm64" ;;
                *)
                    echo "Unsupported Linux arch: $arch" >&2
                    exit 1
                    ;;
            esac
            ;;
        MINGW*|MSYS*|CYGWIN*)
            # Git Bash / MSYS uname reports e.g. MINGW64_NT-10.0-26200
            case "$arch" in
                x86_64) echo "windows64" ;;
                aarch64) echo "windowsarm64" ;;
                *)
                    echo "Unsupported Windows arch: $arch" >&2
                    exit 1
                    ;;
            esac
            ;;
        *)
            echo "Unsupported OS: $os" >&2
            exit 1
            ;;
    esac
}

# Pick a working python interpreter. On Windows the `python3` on PATH is
# often just the Microsoft Store stub that exits without running anything,
# so verify it can actually execute code before trusting it.
find_python() {
    local cand
    for cand in python3 python py; do
        if command -v "$cand" >/dev/null 2>&1 \
                && "$cand" -c "import json" >/dev/null 2>&1; then
            echo "$cand"
            return 0
        fi
    done
    return 1
}

# sha1_of <file> — print a SHA-1 hex digest using whatever is available
# (Linux ships sha1sum; macOS ships shasum). Prints nothing if neither exists.
sha1_of() {
    if command -v sha1sum &>/dev/null; then
        sha1sum "$1" | cut -d' ' -f1
    elif command -v shasum &>/dev/null; then
        shasum -a 1 "$1" | cut -d' ' -f1
    fi
}

pick_build() {
    local platform="$1"
    local want_version="${2:-}"

    local index_data
    index_data="$(curl -fsSL "$CEF_INDEX")"

    local py_script
    py_script="$(mktemp)"
    trap 'rm -f "$py_script"' RETURN

    cat > "$py_script" <<'PY'
import json, sys

platform = sys.argv[1]
want_version = sys.argv[2]  # empty string = latest

data = json.load(sys.stdin)
versions = data[platform]["versions"]

def version_key(cef_ver):
    # e.g. "130.1.14+g1234567+chromium-130.0.6723.116" -> (130, 1, 14)
    # Plain lexicographic sort breaks once any component reaches 2+ digits
    # (e.g. "9.0.0" would sort after "10.0.0"), so compare numeric tuples.
    core = cef_ver.split("+")[0]
    return tuple(int(p) for p in core.split(".") if p.isdigit())

# Stable builds only, full binary (no _tools/_client/_minimal/_release_symbols suffix)
candidates = []
for v in versions:
    if v.get("channel") != "stable":
        continue
    cef_ver = v["cef_version"]
    if want_version and want_version not in cef_ver:
        continue
    for f in v.get("files", []):
        name = f["name"]
        if not name.endswith(".tar.bz2"):
            continue
        if "_tools" in name or "_client" in name or "_minimal" in name \
                or "_release_symbols" in name or "_debug_symbols" in name:
            continue
        # skip platform-specific sub-arches (e.g. linux64 vs linuxarm64)
        if "_arm64" in name and platform == "linux64":
            continue
        candidates.append((cef_ver, v["chromium_version"], name, f["size"], f.get("sha1", "")))
        break  # first matching file (full binary) is enough

if not candidates:
    sys.stderr.write(f"No CEF build found for platform={platform} version={want_version or 'latest'}\n")
    sys.exit(1)

candidates.sort(key=lambda c: version_key(c[0]), reverse=True)
cef_ver, chr_ver, name, size, sha1 = candidates[0]
print(f"{cef_ver}|{chr_ver}|{name}|{size}|{sha1}")
PY

    "$PYTHON" "$py_script" "$platform" "$want_version" <<<"$index_data"
}

# ── main ───────────────────────────────────────────────────────────────────────

require_cmd curl
PYTHON="$(find_python || true)"
if [[ -z "$PYTHON" ]]; then
    echo "✗ Required command not found: python3 (with the json module)" >&2
    exit 1
fi

TARGET_VERSION=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --version) TARGET_VERSION="$2"; shift 2 ;;
        --help|-h)
            echo "Usage: $0 [--version <cef_version_substring>]"
            exit 0
            ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

PLATFORM="$(detect_platform)"
echo "→ Detected platform: $PLATFORM"

echo "→ Querying CEF builds index…"
BUILD_LINE="$(pick_build "$PLATFORM" "$TARGET_VERSION")"
CEF_VERSION="$(cut -d'|' -f1 <<<"$BUILD_LINE")"
CHR_VERSION="$(cut -d'|' -f2 <<<"$BUILD_LINE")"
FILENAME="$(cut -d'|' -f3 <<<"$BUILD_LINE")"
SIZE_BYTES="$(cut -d'|' -f4 <<<"$BUILD_LINE")"
SHA1="$(cut -d'|' -f5 <<<"$BUILD_LINE")"
SIZE_MB=$(( SIZE_BYTES / 1024 / 1024 ))

echo "→ Latest stable CEF: $CEF_VERSION (Chromium $CHR_VERSION)"
echo "→ Download: $FILENAME ($SIZE_MB MB)"

URL="https://cef-builds.spotifycdn.com/$FILENAME"
TARBALL="$INSTALL_DIR/$FILENAME"
EXTRACT_DIR="$INSTALL_DIR/$CEF_VERSION"

if [[ -d "$EXTRACT_DIR/include" ]] \
        && { [[ -d "$EXTRACT_DIR/lib" ]] || [[ -d "$EXTRACT_DIR/Release" ]] \
             || [[ -d "$EXTRACT_DIR/Chromium Embedded Framework.framework" ]]; }; then
    echo "→ CEF $CEF_VERSION already installed at $EXTRACT_DIR"
    echo
    echo "✓ CEF is ready."
    echo "  Set: export CEF_ROOT=\"$EXTRACT_DIR\""
    exit 0
fi

echo "→ Installing to: $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"

echo "→ Downloading $SIZE_MB MB…"
if command -v curl &>/dev/null; then
    curl -fSL "$URL" -o "$TARBALL"
elif command -v wget &>/dev/null; then
    wget -q "$URL" -O "$TARBALL"
else
    echo "✗ Need curl or wget to download CEF." >&2
    exit 1
fi

if [[ -n "$SHA1" ]]; then
    echo "→ Verifying checksum…"
    ACTUAL_SHA1="$(sha1_of "$TARBALL")"
    if [[ -z "$ACTUAL_SHA1" ]]; then
        echo "  (skipping — no sha1sum/shasum available on this system)"
    elif [[ "$ACTUAL_SHA1" != "$SHA1" ]]; then
        echo "✗ Checksum mismatch for $FILENAME" >&2
        echo "  expected: $SHA1" >&2
        echo "  actual:   $ACTUAL_SHA1" >&2
        rm -f "$TARBALL"
        exit 1
    fi
fi

echo "→ Extracting…"
tar -xjf "$TARBALL" -C "$INSTALL_DIR"

EXTRACTED_BASENAME="$(tar -tjf "$TARBALL" 2>/dev/null | head -1 | cut -f1 -d/)"
rm -f "$TARBALL"

if [[ -z "$EXTRACTED_BASENAME" || ! -d "$INSTALL_DIR/$EXTRACTED_BASENAME" ]]; then
    echo "✗ Could not determine the extracted CEF directory." >&2
    exit 1
fi

if [[ "$INSTALL_DIR/$EXTRACTED_BASENAME" != "$EXTRACT_DIR" ]]; then
    rm -rf "$EXTRACT_DIR"
    mv "$INSTALL_DIR/$EXTRACTED_BASENAME" "$EXTRACT_DIR"
fi

echo
echo "✓ CEF installed at: $EXTRACT_DIR"
echo "  Set: export CEF_ROOT=\"$EXTRACT_DIR\""

# Verify expected layout
if [[ -d "$EXTRACT_DIR/include" ]]; then
    echo "  Headers: $EXTRACT_DIR/include (found $(ls "$EXTRACT_DIR/include"/*.h 2>/dev/null | wc -l | tr -d ' ') headers)"
fi
if [[ -d "$EXTRACT_DIR/lib" ]]; then
    echo "  Libs:    $EXTRACT_DIR/lib/ ($(ls "$EXTRACT_DIR/lib"/libcef* 2>/dev/null | wc -l | tr -d ' ') libcef files)"
fi