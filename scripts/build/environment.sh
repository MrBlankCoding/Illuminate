# Shared Qt, CEF, and packaging helper functions.

cpu_cores() {
    if (( IS_MAC )); then
        sysctl -n hw.logicalcpu
    else
        nproc
    fi
}

# ── Locate Qt ────────────────────────────────────────────────────────────────
version_ge() {
    local v1 v2
    v1="$(grep -oE '[0-9]+(\.[0-9]+)+' <<<"$1" | head -1)"
    v2="$(grep -oE '[0-9]+(\.[0-9]+)+' <<<"$2" | head -1)"
    [[ -z "$v2" ]] && return 0
    [[ -z "$v1" ]] && return 1
    local IFS=.
    local -a a=($v1) b=($v2)
    local i n ai bi
    n=$(( ${#a[@]} > ${#b[@]} ? ${#a[@]} : ${#b[@]} ))
    for (( i = 0; i < n; i++ )); do
        ai="${a[i]:-0}"; bi="${b[i]:-0}"
        (( ai > bi )) && return 0
        (( ai < bi )) && return 1
    done
    return 0
}

# Newest official Qt install (online installer / aqtinstall) on macOS.
find_qt_official_mac() {
    local best="" candidate root
    for root in "$HOME/Qt" "/opt/Qt" "/usr/local/Qt" "/Applications/Qt"; do
        [[ -d "$root" ]] || continue
        while IFS= read -r candidate; do
            [[ -f "$candidate/lib/cmake/Qt6/Qt6Config.cmake" ]] || continue
            if [[ -z "$best" ]] || version_ge "$candidate" "$best"; then
                best="$candidate"
            fi
        done < <(find "$root" -maxdepth 2 -type d -name "macos" 2>/dev/null | grep "/6\.")
    done
    echo "$best"
}

find_qt() {
    if [[ -n "${QT_DIR:-}" ]]; then
        echo "$QT_DIR"
        return
    fi

    # Prefer official Qt on macOS: it targets old macOS releases, while
    # Homebrew bottles are built for the host OS (e.g. QtQuick needs macOS 27).
    if (( IS_MAC )); then
        local official
        official="$(find_qt_official_mac)"
        if [[ -n "$official" ]]; then
            echo "$official"
            return
        fi
    fi

    if command -v qmake6 &>/dev/null; then
        qmake6 -query QT_INSTALL_PREFIX
        return
    fi
    if command -v qmake &>/dev/null; then
        local prefix
        prefix="$(qmake -query QT_INSTALL_PREFIX 2>/dev/null || true)"
        if [[ -n "$prefix" ]] && {
            [[ "$prefix" == *Qt* || "$prefix" == *qt* ]] || \
            [[ -f "$prefix/lib/cmake/Qt6/Qt6Config.cmake" ]]
        }; then
            echo "$prefix"
            return
        fi
    fi

    local best=""
    local candidate
    if (( ! IS_MAC )); then
        while IFS= read -r candidate; do
            [[ -f "$candidate/lib/cmake/Qt6/Qt6Config.cmake" ]] || continue
            if [[ -z "$best" ]] || version_ge "$candidate" "$best"; then
                best="$candidate"
            fi
        done < <(find /usr /usr/local /opt -maxdepth 7 -type f \
                    -name Qt6Config.cmake -path "*/lib/cmake/Qt6/*" 2>/dev/null \
                    | sed -E 's#/lib(64)?/([^/]*/)?cmake/Qt6/Qt6Config\.cmake$##' \
                    | sort -u)
    fi

    echo "$best"
}

clean_app_data() {
    (( DO_CLEAN )) || return 0
    (( DO_KEEP_DATA )) && { echo "→ Keeping app data (--keep-data)."; return 0; }
    echo "→ Removing app data…"
    if (( IS_MAC )); then
        if pgrep -f "illuminate.app/Contents/MacOS/illuminate" >/dev/null 2>&1; then
            echo "  Quitting other running copies…"
            pkill -KILL -f "illuminate.app/Contents/MacOS/illuminate" || true
        fi
        rm -rf \
            "$HOME/Library/Application Support/illuminate" \
            "$HOME/Library/Caches/illuminate" \
            "$HOME/Library/Application Support/logs/browser.log" \
            "$HOME/Library/Application Support/logs/browser.log.1"
        local plist domain
        for plist in "$HOME/Library/Preferences/"*[Ii]lluminate*.plist \
                     "$HOME/Library/Preferences/ByHost/"*[Ii]lluminate*.plist; do
            [[ -e "$plist" ]] || continue
            domain="$(basename "$plist" .plist)"
            echo "  Clearing prefs: $domain"
            if [[ "$plist" == */ByHost/* ]]; then
                defaults -currentHost delete "${domain%.*}" >/dev/null 2>&1 || true
            else
                defaults delete "$domain" >/dev/null 2>&1 || true
            fi
            rm -f "$plist"
        done
    else
        rm -rf \
            "${XDG_DATA_HOME:-$HOME/.local/share}/illuminate" \
            "${XDG_CACHE_HOME:-$HOME/.cache}/illuminate" \
            "${XDG_CONFIG_HOME:-$HOME/.config}/illuminate" \
            "${XDG_CONFIG_HOME:-$HOME/.config}/illuminate.local"
    fi
}

# ── Dependencies ─�────────────────────────────────────────────────────────────

find_cef() {
    local candidate

    # 1. Explicit CEF_ROOT (env or cache)
    if [[ -n "${CEF_ROOT:-}" ]]; then
        [[ -d "$CEF_ROOT" ]] && { echo "$CEF_ROOT"; return 0; }
    fi

    # 2. CMake cache
    if [[ -f "$BUILD_DIR/CMakeCache.txt" ]]; then
        candidate="$(sed -n 's/^CEF_ROOT:PATH=//p' "$BUILD_DIR/CMakeCache.txt" 2>/dev/null || true)"
        [[ -n "$candidate" && -d "$candidate" ]] && { echo "$candidate"; return 0; }
    fi

    # 3. Standard install locations
    for candidate in "$HOME/cef"/* "$HOME/cef" "$HOME/cef/latest" "/opt/cef" "/usr/local/cef"; do
        if [[ -d "$candidate/include" ]] && { ls -d "$candidate"/Release/libcef* >/dev/null 2>&1 || ls -d "$candidate"/Release/*.framework >/dev/null 2>&1; }; then
            echo "$candidate"
            return 0
        fi
    done

    # 4. CMake prefix search result (set by find_cef_via_prefix below)
    if [[ -n "${CEF_PREFIX:-}" ]] && [[ -d "${CEF_PREFIX:-}" ]]; then
        echo "$CEF_PREFIX"
        return 0
    fi

    return 1
}

# Try to locate CEF through cmake's find_package mechanism
find_cef_via_prefix() {
    local prefix candidates
    # Collect candidate prefixes: CEF_ROOT dirs + common install paths
    candidates=()
    [[ -n "${CEF_ROOT:-}" ]] && candidates+=("$CEF_ROOT")
    candidates+=("$HOME/cef" "/opt/cef" "/usr/local/cef")

    for prefix in "${candidates[@]}"; do
        [[ -d "$prefix" ]] || continue
        # Quick check: CEF ships a cmake config under lib/
        if ls "$prefix"/lib/cef_config.cmake* "$prefix"/lib/cmake/cef* 2>/dev/null | head -1 | grep -q .; then
            echo "$prefix"
            return 0
        fi
    done
    return 1
}

maybe_install_cef() {
    # Only auto-install if the install script exists and we're interactive
    local script="$SCRIPT_DIR/install-cef.sh"
    [[ -x "$script" ]] || script="${BASH_SOURCE[0]/build.sh/install-cef.sh}"
    if [[ -x "$script" ]]; then
        echo "→ CEF not found. Running installer ($script)…"
        if "$script"; then
            export CEF_ROOT
            CEF_ROOT=""
            # Re-detect after install
            CEF_ROOT="$(find_cef || true)"
            if [[ -n "$CEF_ROOT" ]]; then
                echo "✓ CEF auto-installed at: $CEF_ROOT"
                return 0
            fi
        fi
    fi
    echo "✗ Could not find or install CEF."
    return 1
}


has_compiler() {
    if (( IS_MAC )); then
        xcode-select -p >/dev/null 2>&1
    else
        command -v c++ >/dev/null 2>&1 || command -v g++ >/dev/null 2>&1 || command -v clang++ >/dev/null 2>&1
    fi
}

# Lowest macOS the Qt frameworks we link can load on (highest minos among them).
qt_min_macos() {
    local prefix="$1" mod bin v max="0"
    for mod in Core Gui Network OpenGL Qml Quick QuickControls2 Widgets PrintSupport Sql; do
        bin="$prefix/lib/Qt$mod.framework/Qt$mod"
        [[ -e "$bin" ]] || continue
        v="$(otool -l "$bin" 2>/dev/null | awk '
            /LC_BUILD_VERSION|LC_VERSION_MIN_MACOSX/ { f = 1 }
            f && ($1 == "minos" || $1 == "version") { print $2; exit }')"
        [[ -n "$v" ]] && version_lt "$max" "$v" && max="$v"
    done
    [[ "$max" != "0" ]] && echo "$max"
    return 0
}

# version_lt A B — true when dotted version A sorts before B
version_lt() { ! version_ge "$1" "$2"; }

MISSING=()
QT_PREFIX=""

check_deps() {
    MISSING=()
    has_compiler || MISSING+=("C++ compiler")
    command -v cmake >/dev/null 2>&1 || MISSING+=("cmake")
    command -v ninja >/dev/null 2>&1 || MISSING+=("ninja")
    QT_PREFIX="$(find_qt)"
    if [[ -z "$QT_PREFIX" ]]; then
        MISSING+=("Qt 6")
    fi

    # CEF — try to auto-install if missing
    if CEF_ROOT="$(find_cef 2>/dev/null || true)" && [[ -n "$CEF_ROOT" ]]; then
        export CEF_ROOT
    else
        CEF_PREFIX="$(find_cef_via_prefix 2>/dev/null || true)"
        if [[ -n "$CEF_PREFIX" ]]; then
            export CEF_ROOT="$CEF_PREFIX"
            CEF_ROOT="$CEF_PREFIX"
        elif maybe_install_cef; then
            export CEF_ROOT
        else
            MISSING+=("CEF (Chromium Embedded Framework)")
        fi
    fi
}

# ── Code signing (macOS) ─────────────────────────────────────────────────────
resolve_codesign_identity() {
    if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
        echo "$CODESIGN_IDENTITY"
        return
    fi
    local _id
    _id="$(security find-identity -v -p codesigning 2>/dev/null \
           | grep -v CSSMERR | grep -E '"(Apple Development|Developer ID Application):' \
           | head -1 | awk '{print $2}')"
    echo "${_id:--}"
}

# Signs a bundle and its nested helpers/frameworks with the resolved identity.
sign_app_bundle() {
    local _bundle="$1" _identity
    _identity="$(resolve_codesign_identity)"
    if [[ "$_identity" == "-" ]]; then
        echo "→ Signing ad-hoc (no Apple Development identity found; macOS will"
        echo "  re-ask for folder access after every rebuild — set CODESIGN_IDENTITY to fix)"
    else
        echo "→ Signing with identity ${_identity:0:10}…"
    fi
    codesign --force --deep --timestamp=none --sign "$_identity" "$_bundle"
}
