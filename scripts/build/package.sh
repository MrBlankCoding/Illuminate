# Platform package creation. Variables are prepared by build.sh.

package_application() {

    APP_VERSION="$(sed -n 's/^project(illuminate VERSION \([0-9.]*\).*/\1/p' "$SCRIPT_DIR/CMakeLists.txt")"
    if [[ -z "$APP_VERSION" ]]; then
        echo "⚠ Could not read a version from CMakeLists.txt; using 0.0.0 for the package name."
        APP_VERSION="0.0.0"
    fi
    DIST_DIR="$SCRIPT_DIR/dist"
    STAGE_DIR="$DIST_DIR/stage"
    if [[ -d "$STAGE_DIR" ]]; then
        xattr -cr "$STAGE_DIR" 2>/dev/null || true
        chflags -R nouchg "$STAGE_DIR" 2>/dev/null || true
        rm -rf "$STAGE_DIR"
    fi
    rm -rf "$DIST_DIR/illuminate.app"
    mkdir -p "$DIST_DIR"

    if (( IS_MAC )); then
        echo "→ Deploying Qt into the app bundle…"
        MACDEPLOYQT="$QT_PREFIX/bin/macdeployqt"
        [[ -x "$MACDEPLOYQT" ]] || MACDEPLOYQT="$(command -v macdeployqt || true)"
        [[ -n "$MACDEPLOYQT" ]] || { echo "✗ macdeployqt not found under $QT_PREFIX/bin"; exit 1; }
        QT_QML_DIR="$("$QT_PREFIX/bin/qtpaths6" --query QT_INSTALL_QML 2>/dev/null \
                      || "$QT_PREFIX/bin/qmake" -query QT_INSTALL_QML)"

        QML_IMPORTS="$BUILD_DIR/deploy-qml"
        rm -rf "$QML_IMPORTS"
        cp -RL "$QT_QML_DIR" "$QML_IMPORTS"

        STAGED_APP="$STAGE_DIR/illuminate.app"
        mkdir -p "$STAGE_DIR"
        cp -R "$APP_BUNDLE" "$STAGED_APP"

        for _helper in "$STAGED_APP"/Contents/Frameworks/illuminate\ Helper*.app; do
            [[ -d "$_helper" ]] || continue
            codesign --remove-signature "$_helper" >/dev/null 2>&1 || true
            rm -rf "$_helper/Contents/_CodeSignature"
            mkdir -p "$_helper/Contents/Resources"
            codesign --force --sign - "$_helper"
        done
        codesign --remove-signature "$STAGED_APP" >/dev/null 2>&1 || true
        rm -rf "$STAGED_APP/Contents/_CodeSignature"

        CEF_JSON="$STAGED_APP/Contents/Frameworks/Chromium Embedded Framework.framework/Versions/A/Libraries/vk_swiftshader_icd.json"
        CEF_JSON_HOLD="$BUILD_DIR/vk_swiftshader_icd.json"
        if [[ -f "$CEF_JSON" ]]; then
            mv "$CEF_JSON" "$CEF_JSON_HOLD"
        fi

        DEPLOY_LOG="$(mktemp)"
        if ! "$MACDEPLOYQT" "$STAGED_APP" -qmldir="$SCRIPT_DIR/ui" \
                        -qmlimport="$QML_IMPORTS" -no-codesign >"$DEPLOY_LOG" 2>&1; then
            echo "✗ macdeployqt failed:"
            cat "$DEPLOY_LOG"
            rm -f "$DEPLOY_LOG"
            exit 1
        fi
        grep -vE 'libmimerapi|libiodbc|libpq\.5|no file at "/(usr/local|opt/homebrew|Applications/Postgres)|not Mac App store compliant|Cannot resolve rpath|using QList\(|codesign verification error|invalid signature \(code or signature' \
            "$DEPLOY_LOG" >&2 || true
        rm -f "$DEPLOY_LOG"
        if [[ -f "$CEF_JSON_HOLD" ]]; then
            mkdir -p "$(dirname "$CEF_JSON")"
            mv "$CEF_JSON_HOLD" "$CEF_JSON"
        fi
        rm -rf "$QML_IMPORTS"

        # macdeployqt deploys every SQL driver; ODBC/PostgreSQL/Mimer link
        # client libraries that aren't bundled (and can't be resolved), so
        # ship only SQLite.
        for _drv in "$STAGED_APP"/Contents/PlugIns/sqldrivers/*.dylib; do
            [[ -e "$_drv" && "$_drv" != *libqsqlite.dylib ]] && rm -f "$_drv"
        done

        # Official Qt is universal. The relink/verify steps parse single-arch
        # otool output, and the app is only built for this machine's arch, so
        # thin every fat Mach-O down to it.
        _arch="$(uname -m)"
        while IFS= read -r -d '' _bin; do
            file -b "$_bin" 2>/dev/null | grep -q "universal binary" || continue
            lipo -archs "$_bin" 2>/dev/null | grep -qw "$_arch" || continue
            lipo -extract "$_arch" "$_bin" -output "$_bin.thin" && mv -f "$_bin.thin" "$_bin"
        done < <(find "$STAGED_APP" -type f -print0)

        echo "→ Re-pointing leftover absolute dependencies…"
        relink_bundle_deps "$STAGED_APP"

        echo "→ Pruning development payload…"
        prune_release_payload "$STAGED_APP"

        echo "→ Pruning unused Qt payload…"
        prune_release_macpayload "$STAGED_APP"

        echo "→ Verifying no pruned library is still linked…"
        if ! BROKEN_DEPS="$(verify_bundle_deps "$STAGED_APP")"; then
            echo "✗ Deployed bundle has unresolvable dependencies:"
            echo "$BROKEN_DEPS" | head -20
            exit 1
        fi

        echo "→ Verifying no pruned QML module is still imported…"
        if ! MISSING_QML="$(verify_qml_modules "$STAGED_APP/Contents/Resources/qml")"; then
            echo "✗ Deployed bundle is missing QML modules still imported:"
            echo "$MISSING_QML" | head -20
            exit 1
        fi

        BROKEN_LINKS="$(find "$STAGED_APP" -type l ! -exec test -e {} \; -print)"
        if [[ -n "$BROKEN_LINKS" ]]; then
            echo "✗ Deployed bundle has dangling symlinks:"
            echo "$BROKEN_LINKS" | head -10
            exit 1
        fi
        [[ -f "$STAGED_APP/Contents/Frameworks/Chromium Embedded Framework.framework/Chromium Embedded Framework" ]] || {
            echo "✗ Deployed bundle is missing Chromium Embedded Framework.framework"
            exit 1
        }
        for _helper in "" " (Alerts)" " (GPU)" " (Plugin)" " (Renderer)"; do
            [[ -x "$STAGED_APP/Contents/Frameworks/illuminate Helper$_helper.app/Contents/MacOS/illuminate Helper$_helper" ]] || {
                echo "✗ Deployed bundle is missing illuminate Helper$_helper.app"
                exit 1
            }
        done
        [[ -f "$STAGED_APP/Contents/Resources/AppIcon.icns" ]] || {
            echo "✗ Deployed bundle is missing Contents/Resources/AppIcon.icns"
            exit 1
        }

        echo "→ Signing (${CODESIGN_IDENTITY:-ad-hoc})…"
        codesign --force --deep --sign "${CODESIGN_IDENTITY:--}" "$STAGED_APP"
        codesign --verify --deep --strict "$STAGED_APP" || {
            echo "✗ Deployed bundle failed signature verification."
            exit 1
        }

        STRAY_LINKS="$(relink_bundle_deps --check "$STAGED_APP")" || true
        if [[ -n "$STRAY_LINKS" ]]; then
            echo "✗ Deployed bundle still references build-host libraries:"
            echo "$STRAY_LINKS" | head -10
            exit 1
        fi

        DMG_PATH="$DIST_DIR/illuminate-${APP_VERSION}-macos-$(uname -m).dmg"
        echo "→ Creating disk image…"
        ln -s /Applications "$STAGE_DIR/Applications"
        rm -f "$DMG_PATH"
        # hdiutil create is deprecated in favour of diskutil's image create
        DMG_LOG="$(diskutil image create from "$STAGE_DIR" "$DMG_PATH" \
                --volumeName "illuminate" --format UDZO 2>&1 >/dev/null)" || {
            echo "✗ diskutil image create failed:"
            echo "$DMG_LOG"
            exit 1
        }
        rm -rf "$DIST_DIR/illuminate.app"
        mv "$STAGED_APP" "$DIST_DIR/"
        rm -rf "$STAGE_DIR"
        echo "✓ Package: $DMG_PATH"
        echo "  App:     $DIST_DIR/illuminate.app"
    else
        echo "→ Installing into staging tree…"
        cmake --install "$BUILD_DIR" --config "$BUILD_TYPE" --prefix "$STAGE_DIR/usr"
        TAR_PATH="$DIST_DIR/illuminate-${APP_VERSION}-linux-$(uname -m).tar.gz"
        tar -C "$STAGE_DIR" -czf "$TAR_PATH" usr
        rm -rf "$STAGE_DIR"
        echo "✓ Package: $TAR_PATH"
        echo "  Extract to / (or a prefix). CEF is bundled; Qt 6.8+ must be installed."
    fi
}
