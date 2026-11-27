pragma Singleton
import QtQuick
import illuminate.ui as UI
import "ThemePalette.js" as ThemePalette

QtObject {
    id: root

    // Appearance: "system" | "dark" | "light", global rather than per space
    readonly property string mode: (UI.Browser && UI.Browser.themeMode) ? UI.Browser.themeMode : "system"
    readonly property bool isDark: mode === "dark" || (mode === "system" && Application.styleHints.colorScheme === Qt.Dark)
    readonly property bool isMac: Qt.platform.os === "osx"
    readonly property color defaultSeed: Qt.hsla(0.62, 0.35, 0.5, 1)
    readonly property bool hasCustomSeed: UI.Browser ? UI.Browser.themeColor.valid : false
    readonly property color seed: hasCustomSeed ? UI.Browser.themeColor : defaultSeed

    property color animatedSeed: seed
    Behavior on animatedSeed { ColorAnimation { duration: root.durationMid; easing.type: Easing.OutCubic } }

    readonly property var presets: [
        { id: "graphite", name: qsTr("Graphite"), seed: Qt.hsla(0.62, 0.00, 0.5, 1) },
        { id: "slate",    name: qsTr("Slate"),    seed: Qt.hsla(0.60, 0.18, 0.5, 1) },
        { id: "blue",     name: qsTr("Blue"),     seed: Qt.hsla(0.62, 0.35, 0.5, 1) },
        { id: "indigo",   name: qsTr("Indigo"),   seed: Qt.hsla(0.67, 0.70, 0.5, 1) },
        { id: "violet",   name: qsTr("Violet"),   seed: Qt.hsla(0.75, 0.75, 0.5, 1) },
        { id: "plum",     name: qsTr("Plum"),     seed: Qt.hsla(0.85, 0.55, 0.5, 1) },
        { id: "rose",     name: qsTr("Rose"),     seed: Qt.hsla(0.96, 0.80, 0.5, 1) },
        { id: "coral",    name: qsTr("Coral"),    seed: Qt.hsla(0.02, 0.75, 0.5, 1) },
        { id: "amber",    name: qsTr("Amber"),    seed: Qt.hsla(0.11, 0.85, 0.5, 1) },
        { id: "green",    name: qsTr("Green"),    seed: Qt.hsla(0.38, 0.60, 0.5, 1) },
        { id: "mint",     name: qsTr("Mint"),     seed: Qt.hsla(0.43, 0.45, 0.5, 1) },
        { id: "teal",     name: qsTr("Teal"),     seed: Qt.hsla(0.50, 0.65, 0.5, 1) }
    ]

    // for previews of a seed that is not the active one
    function paletteFor(seedColor, dark) { return ThemePalette.paletteForSeed(seedColor, dark) }
    function sameSeed(a, b) {
        const va = ThemePalette.seedVividness(a), vb = ThemePalette.seedVividness(b)
        if (va < 0.02 && vb < 0.02)
            return true
        const dh = Math.abs(ThemePalette.seedHue(a) - ThemePalette.seedHue(b))
        return Math.min(dh, 1 - dh) < 0.01 && Math.abs(va - vb) < 0.02
    }

    readonly property var palette: ThemePalette.paletteForSeed(animatedSeed, isDark)

    // space avatar choices
    readonly property var avatarColors: [
        "#4A90E2", "#2DA7A1", "#F3A43B", "#E86F67",
        "#8A6CFF", "#69B578", "#D96ACF"
    ]
    // what menus call them, in the same order
    readonly property var avatarColorNames: [
        qsTr("Blue"), qsTr("Teal"), qsTr("Orange"), qsTr("Coral"),
        qsTr("Violet"), qsTr("Green"), qsTr("Pink")
    ]

    function luma(c) { return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b }

    readonly property color accent:      palette.accent
    readonly property color onAccent:    palette.onAccent
    // a wash of the accent: selection, highlighted rows; normal text sits on it
    readonly property color accentDim:   Qt.alpha(accent, isDark ? 0.28 : 0.20)

    // surfaces, from the page outward
    readonly property color bg:          palette.bg
    readonly property color surface:     palette.surface
    readonly property color surfaceHigh: palette.surfaceHigh

    // sidebar: the window background, which also shows around the content card.
    // Item states are neutral overlays so they read on any seed; the active
    // item is a lifted pill of the sidebar colour.
    readonly property color sidebarBg:   palette.sidebarBg
    readonly property color itemHover:   Qt.alpha(text, isDark ? 0.07 : 0.055)
    readonly property color itemPressed: Qt.alpha(text, isDark ? 0.12 : 0.10)
    readonly property color itemActive:  Qt.tint(sidebarBg, Qt.alpha("#ffffff", isDark ? 0.10 : 0.62))
    readonly property color itemActiveBorder: Qt.alpha(isDark ? "#ffffff" : "#000000", 0.06)
    readonly property color fieldBg:     Qt.alpha(text, isDark ? 0.07 : 0.06)

    // the rounded card the page sits in
    readonly property color cardBg:      bg
    readonly property color cardBorder:  Qt.alpha(border, isDark ? 0.60 : 0.55)
    readonly property color shadow:      Qt.alpha("#000000", isDark ? 0.50 : 0.16)

    readonly property color text:        palette.text
    readonly property color textMuted:   palette.textMuted
    readonly property color border:      palette.border

    readonly property color danger:      palette.danger
    readonly property color progressBg:  palette.progressBg

    // spacing: 4px grid
    readonly property int space1: 4
    readonly property int space2: 8
    readonly property int space3: 12
    readonly property int space4: 16

    // radii
    readonly property int radiusS:       6
    readonly property int radiusItem:    8           // sidebar buttons, fields
    readonly property int radiusTab:     10
    readonly property int radiusCard:    12          // the web content card
    readonly property int radiusCommand: 18          // floating command bar (phase 2)

    // window chrome
    readonly property int titleBarHeight: 40         // top strip of the sidebar; traffic lights centre in it
    readonly property int menuBarHeight: 28
    readonly property int trafficLightW: 78          // macOS traffic-light safe area
    readonly property int sysControlW:   40          // Windows/Linux control-button width
    // frame around the page take. Sizes ease to their new values.
    readonly property string density: Prefs ? Prefs.uiDensity : "compact"
    function byDensity(compact, normal, cosy) {
        return density === "cosy" ? cosy : density === "normal" ? normal : compact
    }

    property int cardMargin: byDensity(6, 8, 10)     // sidebar colour visible around the card
    Behavior on cardMargin { NumberAnimation { duration: root.durationSlow; easing.type: Easing.OutCubic } }

    // sidebar
    property int sidebarPadding: byDensity(6, 8, 10)
    property int tabRowHeight: byDensity(32, 36, 40)
    property int faviconSize: byDensity(16, 18, 20)
    property int sidebarRowSpacing: byDensity(2, 2, 3)
    property int essentialsTileHeight: byDensity(34, 40, 46)
    property int addressPillHeight: byDensity(30, 32, 34)
    Behavior on sidebarPadding { NumberAnimation { duration: root.durationSlow; easing.type: Easing.OutCubic } }
    Behavior on tabRowHeight { NumberAnimation { duration: root.durationSlow; easing.type: Easing.OutCubic } }
    Behavior on faviconSize { NumberAnimation { duration: root.durationSlow; easing.type: Easing.OutCubic } }
    Behavior on essentialsTileHeight { NumberAnimation { duration: root.durationSlow; easing.type: Easing.OutCubic } }
    Behavior on addressPillHeight { NumberAnimation { duration: root.durationSlow; easing.type: Easing.OutCubic } }
    readonly property int iconButton:    28
    readonly property int sidebarIndent: 14          // per folder level
    readonly property int sidebarMaxIndent: 6        // deeper levels stop indenting

    readonly property int progressH:     2

    // font
    readonly property string fontFamily:  Application.font.family
    // a monospace face every platform has; "monospace" is fontconfig's alias on Linux
    readonly property string monoFontFamily: isMac ? "Menlo"
        : Qt.platform.os === "windows" ? "Consolas" : "monospace"
    readonly property int    fontSizeS:   11
    readonly property int    fontSizeM:   13
    readonly property int    fontSizeL:   15
    readonly property int    fontSizeXL:  17

    // animation: none at all when the system asks for reduced motion
    readonly property bool reduceMotion: UI.System ? UI.System.reduceMotion : false
    readonly property int durationFast:   reduceMotion ? 0 : 120   // hover
    readonly property int durationMid:    reduceMotion ? 0 : 200   // panels
    readonly property int durationSlow:   reduceMotion ? 0 : 300   // space transitions
    readonly property int durationFolder: reduceMotion ? 0 : 150   // folder open/close
    readonly property int folderHoverExpandMs: 600   // drag over a closed folder
    readonly property real pressScale:    reduceMotion ? 1 : 0.97
    // for a one-off duration: motion(180) is 180 ms, or 0 with reduced motion
    function motion(ms) { return root.reduceMotion ? 0 : ms; }
}
