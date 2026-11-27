#!/usr/bin/env bash
if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv zsh)"
elif [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv zsh)"
fi
#
# Usage:
#   ./build.sh              # configure (if needed) + build
#   ./build.sh --run        # build + launch detached (no logs)
#   ./build.sh --dev        # build Debug + run with live logs in terminal
#   ./build.sh --clean      # wipe build dir AND app data
#   ./build.sh --clean --keep-data  # wipe build dir only, keep app data
#   ./build.sh --package    # Release build + distributable package in dist/
#                           # (macOS: deployed .app + .dmg, Linux: .tar.gz)
#   ./build.sh --test       # build + run the test suite

set -euo pipefail

case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
        _qt_win_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
        if command -v cygpath >/dev/null 2>&1; then
            _qt_win_root="$(cygpath -m "$_qt_win_root")"
            export ILLUMINATE_BASH="$(cygpath -m "$(command -v bash)")"
        else
            export ILLUMINATE_BASH="$(command -v bash)"
        fi
        exec powershell.exe -NoProfile -ExecutionPolicy Bypass \
            -File "$_qt_win_root/build.ps1" "$@"
        ;;
esac

if [[ -z "${ILLUMINATE_ROOT:-}" ]]; then
    _qt_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
    _qt_snap="$(mktemp "${TMPDIR:-/tmp}/illuminate_build.XXXXXX")"
    cat -- "${BASH_SOURCE[0]}" > "$_qt_snap"
    chmod +x "$_qt_snap"
    export ILLUMINATE_ROOT="$_qt_root"
    export ILLUMINATE_SNAPSHOT="$_qt_snap"
    exec bash "$_qt_snap" "$@"
fi
trap 'rm -f "${ILLUMINATE_SNAPSHOT:-/dev/null}"' EXIT

SCRIPT_DIR="${ILLUMINATE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
BUILD_DIR="$SCRIPT_DIR/build"
source "$SCRIPT_DIR/scripts/build/environment.sh"
source "$SCRIPT_DIR/scripts/build/bundle.sh"
source "$SCRIPT_DIR/scripts/build/package.sh"

# ── detect OS ────────────────────────────────────────────────────────────────

IS_MAC=0
IS_LINUX=0
case "$(uname -s)" in
    Darwin*) IS_MAC=1   ;;
    Linux)   IS_LINUX=1 ;;
    *)
        echo "✗ Unsupported platform: $(uname -s)"
        exit 1
        ;;
esac

# ── args ─────────────────────────────────────────────────────────────────────

DO_CLEAN=0
DO_KEEP_DATA=0
DO_RUN=0
DO_DEV=0
DO_PACKAGE=0
DO_TEST=0
DO_VERBOSE=0
for arg in "$@"; do
    case "$arg" in
        --clean)     DO_CLEAN=1     ;;
        --keep-data) DO_KEEP_DATA=1 ;;
        --run)    DO_RUN=1     ;;
        --dev)    DO_DEV=1     ;;
        --package) DO_PACKAGE=1 ;;
        --test)    DO_TEST=1    ;;
        --verbose) DO_VERBOSE=1 ;;
        *)
            echo "Unknown argument: $arg"
            echo "Usage: ./build.sh [--clean [--keep-data]] [--run | --dev] [--package] [--test] [--verbose]"
            exit 1
            ;;
    esac
done

if (( DO_PACKAGE )) && (( DO_DEV )); then
    echo "✗ --package builds Release; it can't be combined with --dev."
    exit 1
fi

if (( DO_KEEP_DATA )) && (( ! DO_CLEAN )); then
    echo "Note: --keep-data has no effect without --clean."
fi

if (( DO_RUN )) && (( DO_DEV )); then
    echo "Note: --dev already runs the app in the foreground with live logs; ignoring --run."
    DO_RUN=0
fi

# --verbose implies --dev: it builds Debug CEF and launches under lldb
if (( DO_VERBOSE )) && (( ! DO_DEV )); then
    DO_DEV=1
fi

if (( DO_VERBOSE )); then
    if (( ! IS_MAC )); then
        echo "✗ --verbose (lldb + Debug CEF) is macOS-only."
        exit 1
    fi
    if ! command -v lldb >/dev/null 2>&1; then
        echo "✗ --verbose needs lldb. Install Xcode and run: xcode-select --install"
        exit 1
    fi
fi


check_deps
if (( ${#MISSING[@]} )); then
    echo "✗ Missing build dependencies:"
    printf '    • %s\n' "${MISSING[@]}"
    echo
    echo "  This script builds and packages the app; it doesn't set up your"
    echo "  toolchain. Install the above yourself, then re-run:"
    if (( IS_MAC )); then
        echo "    • Xcode Command Line Tools — xcode-select --install"
        echo "    • cmake, ninja and Qt 6 — brew install cmake ninja qt"
        echo "    • CEF binary distribution — set CEF_ROOT to the extracted path"
        echo "      or install via: ./install-cef.sh"
    else
        echo "    • a C++ compiler, cmake and ninja from your distro's packages"
        echo "    • Qt 6 and the CEF binary distribution for your platform"
        echo "      Set CEF_ROOT to the extracted CEF path before building."
    fi
    if [[ -n "$QT_PREFIX" ]]; then
        echo "  (Qt was found at $QT_PREFIX — ensure CEF_ROOT is also set.)"
    fi
    echo "  Qt installed somewhere nonstandard? Point QT_DIR at its prefix."
    exit 1
fi

OSX_TARGET=""
if (( IS_MAC )); then
    OSX_TARGET="${MACOSX_DEPLOYMENT_TARGET:-26.0}"
    QT_MIN_MACOS="$(qt_min_macos "$QT_PREFIX")"
    if [[ -n "$QT_MIN_MACOS" ]] && version_lt "$OSX_TARGET" "$QT_MIN_MACOS"; then
        if [[ -n "${MACOSX_DEPLOYMENT_TARGET:-}" ]]; then
            echo "⚠ MACOSX_DEPLOYMENT_TARGET=$OSX_TARGET, but the Qt at $QT_PREFIX is built for"
            echo "  macOS $QT_MIN_MACOS+; the app will not launch on anything older than $QT_MIN_MACOS."
        else
            echo "→ Qt at $QT_PREFIX is built for macOS $QT_MIN_MACOS+; targeting $QT_MIN_MACOS instead of $OSX_TARGET."
            echo "  To ship for macOS $OSX_TARGET, point QT_DIR at a Qt built for $OSX_TARGET or older."
            OSX_TARGET="$QT_MIN_MACOS"
        fi
    fi
fi

BUILD_TYPE="Release"
(( DO_DEV )) && BUILD_TYPE="Debug"
TESTING_ARG="OFF"
(( DO_TEST )) && TESTING_ARG="ON"

SCRIPT_DIR="${ILLUMINATE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
BUILD_DIR="$SCRIPT_DIR/build"

if (( DO_VERBOSE )); then
    BUILD_DIR="$SCRIPT_DIR/build-verbose"
fi

APP_LABEL="illuminate"
if (( IS_MAC )); then
    APP_BUNDLE="$BUILD_DIR/illuminate.app"
    APP_BINARY="$APP_BUNDLE/Contents/MacOS/illuminate"
    APP_LABEL="illuminate.app"
else
    APP_BUNDLE=""
    APP_BINARY="$BUILD_DIR/illuminate"
fi

if (( DO_CLEAN )) && [[ -d "$BUILD_DIR" ]]; then
    echo "→ Removing build directory…"
    rm -rf "$BUILD_DIR"
fi

echo "→ Using Qt at: $QT_PREFIX"

if [[ -n "${CEF_ROOT:-}" ]]; then
    echo "→ Using CEF at: $CEF_ROOT"
    export CEF_ROOT
else
    echo "✗ CEF_ROOT is not set and CEF was not found. Run ./install-cef.sh first."
    exit 1
fi

if (( IS_LINUX )); then
    for _cef_lib_dir in "$CEF_ROOT/Release" "$CEF_ROOT/Debug"; do
        if [[ -d "$_cef_lib_dir" ]]; then
            for _cef_file in icudtl.dat resources.pak chrome_100_percent.pak chrome_200_percent.pak; do
                if [[ -f "$CEF_ROOT/Resources/$_cef_file" ]] \
                        && [[ ! -f "$_cef_lib_dir/$_cef_file" ]]; then
                    echo "→ Copying $_cef_file to $_cef_lib_dir"
                    cp "$CEF_ROOT/Resources/$_cef_file" "$_cef_lib_dir/$_cef_file"
                fi
            done
        fi
    done
fi

CEF_DEBUG_ARG="OFF"
(( DO_VERBOSE )) && CEF_DEBUG_ARG="ON"

CONFIGURED_TYPE=""
CONFIGURED_PREFIX=""
CONFIGURED_CEF=""
CONFIGURED_CEF_DEBUG=""
CONFIGURED_TESTING=""
CONFIGURED_OSX_TARGET=""
if [[ -f "$BUILD_DIR/CMakeCache.txt" ]]; then
    CONFIGURED_OSX_TARGET="$(sed -n 's/^CMAKE_OSX_DEPLOYMENT_TARGET:[A-Z]*=//p' "$BUILD_DIR/CMakeCache.txt")"
    CONFIGURED_TYPE="$(sed -n 's/^CMAKE_BUILD_TYPE:[A-Z]*=//p' "$BUILD_DIR/CMakeCache.txt")"
    CONFIGURED_PREFIX="$(sed -n 's/^CMAKE_PREFIX_PATH:[A-Z]*=//p' "$BUILD_DIR/CMakeCache.txt")"
    CONFIGURED_CEF="$(sed -n 's/^CEF_ROOT:PATH=//p' "$BUILD_DIR/CMakeCache.txt" 2>/dev/null || true)"
    CONFIGURED_CEF_DEBUG="$(sed -n 's/^USE_CEF_DEBUG:BOOL=//p' "$BUILD_DIR/CMakeCache.txt" 2>/dev/null || true)"
    CONFIGURED_TESTING="$(sed -n 's/^BUILD_TESTING:BOOL=//p' "$BUILD_DIR/CMakeCache.txt" 2>/dev/null || true)"
fi

if [[ ! -f "$BUILD_DIR/CMakeCache.txt" ]] \
        || [[ "$CONFIGURED_PREFIX" != "$QT_PREFIX" ]] \
        || [[ "$CONFIGURED_CEF" != "$CEF_ROOT" ]] \
        || [[ "$CONFIGURED_CEF_DEBUG" != "$CEF_DEBUG_ARG" ]] \
        || [[ "$CONFIGURED_TESTING" != "$TESTING_ARG" ]] \
        || [[ "$CONFIGURED_OSX_TARGET" != "$OSX_TARGET" ]] \
        || [[ "$CONFIGURED_TYPE" != "$BUILD_TYPE" ]]; then
    NEED_CONFIGURE=1
elif [[ "$SCRIPT_DIR/CMakeLists.txt" -nt "$BUILD_DIR/CMakeCache.txt" ]] \
        || [[ "$SCRIPT_DIR/cmake/IlluminateModule.cmake" -nt "$BUILD_DIR/CMakeCache.txt" ]]; then
    echo "→ CMake configuration changed since last configure; reconfiguring…"
    NEED_CONFIGURE=1
fi

if [[ "${NEED_CONFIGURE:-0}" == "1" ]]; then
    # Qt6*_DIR entries are cached; a different Qt prefix is ignored unless
    # the cache is dropped.
    if [[ -f "$BUILD_DIR/CMakeCache.txt" ]] \
            && { [[ "$CONFIGURED_PREFIX" != "$QT_PREFIX" ]] \
                 || ! grep -q "^Qt6_DIR:PATH=$QT_PREFIX/" "$BUILD_DIR/CMakeCache.txt"; }; then
        echo "→ Qt location changed; clearing CMake cache…"
        rm -rf "$BUILD_DIR/CMakeCache.txt" "$BUILD_DIR/CMakeFiles"
    fi
    if (( DO_VERBOSE )); then
        echo "→ Configuring ($BUILD_TYPE, Debug CEF)…"
    else
        echo "→ Configuring ($BUILD_TYPE)…"
    fi
    if (( IS_LINUX )); then
        cmake -S "$SCRIPT_DIR" \
              -B "$BUILD_DIR"  \
              -G Ninja \
              -DCMAKE_PREFIX_PATH="$QT_PREFIX" \
              -DCEF_ROOT="$CEF_ROOT" \
              -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
              -DBUILD_TESTING="$TESTING_ARG" \
              -DUSE_CEF_DEBUG="$CEF_DEBUG_ARG"
    else
        cmake -S "$SCRIPT_DIR" \
              -B "$BUILD_DIR"  \
              -G Ninja \
              -DCMAKE_PREFIX_PATH="$QT_PREFIX" \
              -DCEF_ROOT="$CEF_ROOT" \
              -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
              -DBUILD_TESTING="$TESTING_ARG" \
              -DUSE_CEF_DEBUG="$CEF_DEBUG_ARG" \
              -DCMAKE_OSX_DEPLOYMENT_TARGET="$OSX_TARGET" \
              -DCMAKE_OSX_SYSROOT="/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
    fi
fi

app_pids() {
    pgrep -f "illuminate\.app/Contents/MacOS/illuminate" 2>/dev/null | while read -r _pid; do
        [[ "$(ps -o command= -p "$_pid" 2>/dev/null)" == *"/illuminate.app/Contents/MacOS/illuminate"* ]] \
            && [[ "$(ps -o command= -p "$_pid" 2>/dev/null)" != *lldb* ]] \
            && echo "$_pid"
    done
}

lldb_pids() {
    pgrep -f "lldb .*illuminate\.app/Contents/MacOS/illuminate" 2>/dev/null || true
}

if [[ -n "$(app_pids)" ]]; then
    echo "→ Quitting running ${APP_LABEL}…"
    if (( IS_MAC )); then
        osascript -e 'quit app id "local.illuminate.illuminate"' >/dev/null 2>&1 || true
    fi
    for _ in $(seq 1 50); do
        [[ -z "$(app_pids)" ]] && break
        app_pids | xargs -r kill -TERM 2>/dev/null || true
        sleep 0.1
    done
    if [[ -n "$(app_pids)" ]]; then
        echo "  Still running after 5s; killing it."
        app_pids | xargs -r kill -KILL 2>/dev/null || true
        sleep 0.2
    fi

    pgrep -f "illuminate Helper" 2>/dev/null | xargs -r kill -KILL 2>/dev/null || true
    [[ -n "$(app_pids)" ]] && { echo "✗ Could not stop the running instance; aborting."; exit 1; }
    # Only now that the inferior is gone, drop the debugger left holding it.
    lldb_pids | xargs -r kill -TERM 2>/dev/null || true
fi

clean_app_data

[[ -n "$APP_BUNDLE" ]] && rm -rf "$APP_BUNDLE"

if (( IS_MAC )); then
    export MACOSX_DEPLOYMENT_TARGET="$OSX_TARGET"
    export SDKROOT="/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
    echo "MACOSX_DEPLOYMENT_TARGET: ${MACOSX_DEPLOYMENT_TARGET:-not set}"
    echo "SDKROOT: ${SDKROOT:-not set}"
fi
echo "TARGET_BUILD_DIR: ${TARGET_BUILD_DIR:-not set}"

echo "→ Building…"
cmake --build "$BUILD_DIR" --config "$BUILD_TYPE" --parallel "$(cpu_cores)"

if (( DO_TEST )); then
    echo "→ Running tests…"
    ctest --test-dir "$BUILD_DIR" --build-config "$BUILD_TYPE" --output-on-failure
    exit 0
fi

if (( IS_MAC )); then
    if [[ -d "$APP_BUNDLE/Contents/Frameworks/QtCore.framework" ]] || [[ -d "$APP_BUNDLE/Contents/PlugIns" ]]; then
        echo "→ Removing previously deployed Qt frameworks (dev bundle runs against dev Qt)…"
        rm -rf "$APP_BUNDLE"
        cmake --build "$BUILD_DIR" --target illuminate --config "$BUILD_TYPE" \
              --parallel "$(cpu_cores)"
    fi
fi

if [[ -f "$APP_BINARY" ]]; then
    echo "✓ Build succeeded."
    if (( IS_MAC )); then
        echo "  App bundle: $APP_BUNDLE"
    else
        echo "  Binary: $APP_BINARY"
    fi
else
    echo "✗ Build finished but binary not found at expected path: $APP_BINARY"
    exit 1
fi

if (( DO_PACKAGE )); then
    package_application
fi

# ── run (detached) ───────────────────────────────────────────────────────────

if (( DO_RUN )) && (( ! DO_DEV )); then
    echo "→ Launching ${APP_LABEL} (detached)…"
    if (( IS_MAC )); then
        open "$APP_BUNDLE"
    else
        nohup "$APP_BINARY" >/dev/null 2>&1 &
        disown
        echo "  PID: $!"
    fi
fi

# ── dev (foreground, live logs) ──────────────────────────────────────────────

if (( DO_DEV )); then
    if [[ ! -f "$APP_BINARY" ]]; then
        echo "✗ Binary not found at expected path: $APP_BINARY"
        exit 1
    fi

    if (( IS_MAC )); then
        LOG_DIR="$HOME/Library/Application Support/logs"
    else
        LOG_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/illuminate/illuminate/logs"
    fi
    mkdir -p "$LOG_DIR"
    LOG_FILE="$LOG_DIR/browser.log"

    echo "  Log file: $LOG_FILE"

    # dev builds: CEF --no-sandbox is set via CefManager settings
    if (( DO_VERBOSE )); then
        echo "→ Launching under lldb (Debug CEF, symbols available)…"
        echo "  Reproduce the crash, then at the (lldb) prompt:"
        echo "    bt                 backtrace of the trapping thread"
        echo "    thread backtrace -c 40"
        echo "    thread list        which thread trapped"
        echo "  V8/Chromium log: stderr (this terminal) + chrome_debug.log"
        echo

        LLDB_ARGS=(
            -o "settings set target.process.stop-on-sharedlibrary-events false"
            -o "process handle -p true -s false -n false SIGTRAP"
            -o "run"
        )

        ILLUMINATE_VERBOSE_CEF=1 lldb "${LLDB_ARGS[@]}" -- "$APP_BINARY"
        exit $?
    fi

    "$APP_BINARY" 2>&1 | tee -a "$LOG_FILE" &
    APP_PID=$!
    trap 'kill "$APP_PID" 2>/dev/null; exit 0' INT TERM
    wait "$APP_PID"
fi
