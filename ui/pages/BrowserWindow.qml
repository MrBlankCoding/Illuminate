import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import illuminate.ui

pragma ComponentBehavior: Bound

Window {
    id: root
    visible: true
    visibility: Window.Maximized
    width: 1280
    height: 840
    minimumWidth: 640
    minimumHeight: 420
    title: (Browser.activeTitle || "New Tab") + " — illuminate"
    color: Theme.sidebarBg
    readonly property bool frameless: !Theme.isMac
    flags: frameless
        ? Qt.Window | Qt.FramelessWindowHint
        : Qt.Window | (Theme.isMac ? Qt.ExpandedClientAreaHint | Qt.NoTitleBarBackgroundHint : 0)
    readonly property bool contentFullScreen: workspace.viewStack.activeWebView ? workspace.viewStack.activeWebView.fullScreen : false
    property bool fullScreenForContent: false
    property bool contentFullScreenShown: false
    property int visibilityBeforeContentFullScreen: Window.Windowed
    property int visibilityBeforeWindowFullScreen: Window.Windowed
    property rect geometryBeforeFullScreen: Qt.rect(0, 0, 1280, 840)
    property bool restoreGeometryAfterFullScreen: false
    property var uiFocusClaims: []
    // the page extensions act on
    readonly property CefBrowser activeWebView: workspace.viewStack.activeWebView
    // other spaces' last pages, kept ready for an instant switch
    readonly property var warmSpaces: workspace.warmSpaces
    property bool inputOverlayOpen: false

    onVisibleChanged: Logger.debug("Diag", "BrowserWindow visible=" + root.visible + " visibility=" + root.visibility)
    onActiveChanged: Logger.debug("Diag", "BrowserWindow active=" + root.active + " visibility=" + root.visibility)

    function syncInputOverlayOpen() {
        const commandVisible = commandBar && commandBar.visible;
        root.inputOverlayOpen = commandVisible || root.uiFocusClaims.length > 0;
    }

    function claimUiFocus(owner) {
        if (!owner || root.uiFocusClaims.includes(owner))
            return;
        root.uiFocusClaims = root.uiFocusClaims.concat([owner]);
        root.syncInputOverlayOpen();
    }

    function releaseUiFocus(owner) {
        if (!owner)
            return;
        root.uiFocusClaims = root.uiFocusClaims.filter(claim => claim !== owner);
        root.syncInputOverlayOpen();
    }

    signal focusReturnedToWeb()

    function returnFocusToWeb() {
        root.uiFocusClaims = [];
        root.syncInputOverlayOpen();
        if (commandBar.visible)
            commandBar.close();
        root.focusReturnedToWeb();
        if (workspace.viewStack.activeWebView)
            workspace.viewStack.activeWebView.forceActiveFocus();
    }
    function rememberWindowGeometry() {
        if (root.visibility === Window.FullScreen || root.restoreGeometryAfterFullScreen)
            return;
        root.geometryBeforeFullScreen = Qt.rect(root.x, root.y, root.width, root.height);
        root.visibilityBeforeWindowFullScreen = root.visibility;
    }

    onXChanged: root.rememberWindowGeometry()
    onYChanged: root.rememberWindowGeometry()
    onWidthChanged: root.rememberWindowGeometry()
    onHeightChanged: root.rememberWindowGeometry()

    function restoreWindowAfterFullScreen() {
        // AppKit preserves/restores the exact NSWindow frame around its native
        // fullscreen transition. The QML fallback is for frameless platforms.
        root.restoreGeometryAfterFullScreen = !Theme.isMac
            && root.visibilityBeforeWindowFullScreen !== Window.Maximized;
        if (root.visibilityBeforeWindowFullScreen === Window.Maximized) {
            root.showMaximized();
        } else {
            root.showNormal();
        }
    }

    function toggleFullScreen() {
        if (root.visibility === Window.FullScreen) {
            root.restoreWindowAfterFullScreen();
            return;
        }
        root.rememberWindowGeometry();
        root.showFullScreen();
    }

    function syncMacWindowButtons() {
        if (Theme.isMac) {
            const fullscreen = root.visibility === Window.FullScreen;
            const buttonsVisible = fullscreen || !root.sidebarCollapsed;
            WindowHelper.setWindowButtonsVisible(root, buttonsVisible);
        }
    }

    onContentFullScreenChanged: {
        if (root.retiring)
            return;
        if (contentFullScreen) {
            if (root.visibility !== Window.FullScreen) {
                root.visibilityBeforeContentFullScreen = root.visibility;
                root.rememberWindowGeometry();
                root.fullScreenForContent = true;
                root.showFullScreen();
            }
        } else if (root.fullScreenForContent) {
            root.fullScreenForContent = false;
            root.contentFullScreenShown = false;
            root.restoreWindowAfterFullScreen();
        }
    }

    onVisibilityChanged: {
        Logger.debug("Diag", "BrowserWindow visibility=" + root.visibility + " visible=" + root.visible + " active=" + root.active);
        root.syncMacWindowButtons();
        if (root.visibility !== Window.FullScreen) {
            root.visibilityBeforeWindowFullScreen = root.visibility;
            if (root.restoreGeometryAfterFullScreen) {
                fullScreenGeometryRestoreTimer.restart();
            }
        }

        if (!root.contentFullScreen)
            return;
        if (root.visibility === Window.FullScreen)
            root.contentFullScreenShown = true;
        else if (root.contentFullScreenShown && workspace.viewStack.activeWebView)
            workspace.viewStack.activeWebView.exitFullScreen();
    }

    // Native fullscreen transitions can report Windowed before AppKit has
    // finished animating back to the saved frame. Restore after that transition.
    Timer {
        id: fullScreenGeometryRestoreTimer
        interval: 700
        repeat: false
        onTriggered: {
            if (!root.restoreGeometryAfterFullScreen || root.visibility === Window.FullScreen)
                return;
            const previous = root.geometryBeforeFullScreen;
            root.x = previous.x;
            root.y = previous.y;
            root.width = previous.width;
            root.height = previous.height;
            root.restoreGeometryAfterFullScreen = false;
        }
    }



    // closing (with skipCloseConfirm set) releases the window in onClosing
    function retire() {
        root.retiring = true
        root.skipCloseConfirm = true
        root.replacedByNewWindow = true
        root.close();
    }

    property Window settingsWindow: null
    property bool skipCloseConfirm: false
    property bool replacedByNewWindow: false
    property bool retiring: false
    signal windowClosed

    function requestWindowClose() {
        if (Browser.confirmCloseRequired()) {
            windowDialogs.closeDialog.open()
            return
        }
        root.closeAfterPageCheck()
    }

    // what to do once every page has agreed to close: "close" or "quit"
    property string afterPageCheck: ""

    // pages with unsaved changes get their "Leave site?" first
    function closeAfterPageCheck() {
        root.afterPageCheck = "close"
        Browser.closeAllPages()
    }
    function quitAfterPageCheck() {
        root.afterPageCheck = "quit"
        Browser.closeAllPages()
    }

    Connections {
        target: Browser
        enabled: root.afterPageCheck !== ""
        function onAllPagesClosed() {
            const next = root.afterPageCheck
            root.afterPageCheck = ""
            if (next === "quit") {
                Qt.quit()
            } else {
                root.skipCloseConfirm = true
                root.close()
            }
        }
        function onCloseAllPagesCancelled() {
            root.afterPageCheck = ""
        }
    }

    onClosing: function(close) {
        Logger.debug("Diag", "BrowserWindow onClosing accepted=" + close.accepted + " skip=" + root.skipCloseConfirm);
        if (root.skipCloseConfirm) {
            if (!root.replacedByNewWindow)
                root.windowClosed()
            Browser.releaseWindow(root)
            return;
        }
        // the close button, ⌘W on the last tab, or quitting from the Dock
        close.accepted = false
        if (Browser.confirmCloseRequired())
            windowDialogs.closeDialog.open()
        else if (root.afterPageCheck === "")
            root.closeAfterPageCheck()
    }

    readonly property bool sidebarCollapsed: Prefs.sidebarCollapsed
    property bool sidebarDockCollapsed: Prefs.sidebarCollapsed
    onSidebarCollapsedChanged: {
        root.syncMacWindowButtons();
        if (!root.sidebarCollapsed) {
            workspace.stopDockSlideOut();
            root.sidebarDockCollapsed = false;
            workspace.dockLoader.x = -workspace.dockLoader.width;
            workspace.dockLoader.opacity = 0;
            Qt.callLater(workspace.startDockSlideIn);
        } else {
            if (!root.sidebarDockCollapsed)
                workspace.startDockSlideOut();
        }
    }

    function toggleSidebar() {
        Prefs.sidebarCollapsed = !root.sidebarCollapsed;
    }

    function raiseActiveWebView() {
        if (workspace.viewStack.activeWebView)
            workspace.viewStack.activeWebView.refreshNativeView(true);
    }

    // Route sidebar shortcuts to the single dock instance.
    function forEachSidebar(action) {
        if (workspace.dockLoader.item)
            action(workspace.dockLoader.item);
    }

    function openCommandBar(mode) {
        const url = Browser.activeUrl;
        if (mode === "edit" && url !== "" && url !== "newtab://newtab")
            commandBar.openEdit(url);
        else
            commandBar.openNew();
    }

    function openStartupCommandBar() {
        if (Browser.activeUrl === "newtab://newtab")
            root.openCommandBar("new");
    }

    function toggleBookmark() {
        const url = Browser.activeUrl;
        if (url === "" || url === "newtab://newtab")
            return;
        Bookmarks.toggleBookmark(Browser.activeTitle, url, Browser.activeIconUrl);
    }

    function openSettings() {
        if (settingsWindow && settingsWindow.visible) {
            settingsWindow.close();
            return;
        }
        if (!settingsWindow) {
            const component = Qt.createComponent("qrc:/illuminate/ui/pages/SettingsWindow.qml");
            if (component.status !== Component.Ready) {
                Logger.error("BrowserWindow", "Settings window failed to load: " + component.errorString());
                return;
            }
            settingsWindow = component.createObject(root, { transientParent: root }) as Window;
            if (!settingsWindow)
                return;
            settingsWindow.destroyed.connect(function() {
                settingsWindow = null;
            });
        }
        settingsWindow.show();
        settingsWindow.raise();
        settingsWindow.requestActivate();
    }



    WindowDialogs {
        id: windowDialogs
        browserWindow: root
    }

    PrintController {
        id: printController
        activeWebView: workspace.viewStack.activeWebView
    }

    function printActivePage() { printController.printActivePage(); }
    function savePdfActivePage() { printController.savePdfActivePage(); }
    function openSystemPrintFor(view) { printController.openSystemPrintFor(view); }
    function onPdfPrintingFinished(filePath, success) { printController.onPdfPrintingFinished(filePath, success); }

    Component.onCompleted: {
        Qt.callLater(root.syncInputOverlayOpen);
        Qt.callLater(root.openStartupCommandBar);
        Logger.info("BrowserWindow", "Window ready, platform=" + Qt.platform.os);
        WindowHelper.applyTitleBarStyle(root, Theme.titleBarHeight);
        root.syncMacWindowButtons();
        AppMenu.attach(root);
    }

    Component.onDestruction: AppMenu.detach(root)

    BrowserWorkspace {
        id: workspace
        browserWindow: root
        themePicker: themePickerPopup
    }

    CommandBar {
        id: commandBar
        onVisibleChanged: root.syncInputOverlayOpen()
        quickActions: [
            { label: "Toggle Sidebar", icon: "qrc:/illuminate/ui/icons/panel-left.svg", run: () => root.toggleSidebar() },
            { label: "Open Settings", icon: "qrc:/illuminate/ui/icons/more-vertical.svg", run: () => root.openSettings() },
            { label: "Downloads", icon: "qrc:/illuminate/ui/icons/download.svg", run: () => Browser.newTab("chrome://downloads/") },
            { label: "Find in Page", icon: "qrc:/illuminate/ui/icons/search.svg", run: () => Browser.executeChromeCommand("find") },
            { label: "Copy URL", icon: "qrc:/illuminate/ui/icons/copy.svg", run: () => Browser.copyActiveUrl() },
            { label: "Extensions", icon: "qrc:/illuminate/ui/icons/square.svg", run: () => Browser.newTab("chrome://extensions/") },
            { label: "History", icon: "qrc:/illuminate/ui/icons/search.svg", run: () => Browser.newTab("chrome://history/") },
            { label: "New Tab", icon: "qrc:/illuminate/ui/icons/plus.svg", run: () => Browser.newTab("newtab://newtab") },
            { label: "Close Tab", icon: "qrc:/illuminate/ui/icons/x.svg", run: () => Browser.closeTab(Browser.tabModel.activeIndex) },
            { label: "Duplicate Tab", icon: "qrc:/illuminate/ui/icons/copy.svg", run: () => {
                const url = Browser.activeUrl;
                if (url && url !== "")
                    Browser.newTab(url);
            }},
            { label: "Mute / Unmute Tab", icon: "qrc:/illuminate/ui/icons/volume-x.svg", run: () => {
                const tab = Browser.tabModel.tabAt(Browser.tabModel.activeIndex);
                if (tab)
                    Browser.toggleTabMuted(tab.id);
            }},
            { label: "Reload Page", icon: "qrc:/illuminate/ui/icons/rotate-cw.svg", run: () => Browser.reload() },
            { label: "Bookmark Page", icon: "qrc:/illuminate/ui/icons/star.svg", run: () => root.toggleBookmark() },
            { label: "Theme Picker", icon: "qrc:/illuminate/ui/icons/sun.svg", run: () => themePickerPopup.open() },
            { label: "Toggle Full Screen", icon: "qrc:/illuminate/ui/icons/monitor.svg", run: () => root.toggleFullScreen() },
            { label: "Close Other Tabs", icon: "qrc:/illuminate/ui/icons/x.svg", run: () => {
                const active = Browser.tabModel.activeIndex;
                for (let i = Browser.tabModel.count - 1; i >= 0; --i) {
                    if (i !== active)
                        Browser.closeTab(i);
                }
            }}
        ]
    }

    Toast {
        id: toast
        x: workspace.dockWidth + Math.round((root.width - workspace.dockWidth - width) / 2)
        y: root.height - height - 28
    }

    Connections {
        target: Browser
        function onLinkCopied() {
            toast.show(qsTr("Link copied"), "qrc:/illuminate/ui/icons/check.svg")
        }
    }

    Connections {
        target: Downloads
        enabled: root.sidebarDockCollapsed
        function onDownloadFinished(fileName) {
            toast.show(qsTr("Downloaded %1").arg(fileName), "qrc:/illuminate/ui/icons/download.svg")
        }
    }

    ThemePicker {
        id: themePickerPopup
        focusRouter: root
        popupType: Popup.Window
        x: workspace.dockWidth + Theme.cardMargin - 6
        y: Math.max(8, Math.round((root.height - implicitHeight) / 2))

        showArrow: true
        arrowOffset: 0
    }

    ResizeGrips {
        anchors.fill: parent
        visible: root.frameless && root.visibility === Window.Windowed
        z: 1000
        onRequestSystemResize: edges => root.startSystemResize(edges)
    }

    KeyboardShortcuts {
        browser: Browser
        activeWebView: workspace.viewStack.activeWebView
        logger: Logger
        appMenu: AppMenu
        shortcuts: Shortcuts

        onSettingsRequested: root.openSettings()
        onSpaceSwitchRequested: spaceId => {
            const space = Spaces.spaceById(spaceId);
            if (space)
                Spaces.activeSpace = space;
            else
                Logger.warning("BrowserWindow", "No space with id " + spaceId);
        }
        // the editor lives in the sidebar, which may be in either loader
        onNewSpaceRequested: root.forEachSidebar(sidebar => sidebar.openSpaceEditor(null))
        onThemeRequested: themePickerPopup.open()
        onCommandBarRequested: mode => root.openCommandBar(mode)
        onSidebarToggleRequested: root.toggleSidebar()
        onBookmarkToggleRequested: root.toggleBookmark()
        onPrintRequested: root.printActivePage()
        onSavePdfRequested: root.savePdfActivePage()
        onFullScreenRequested: root.toggleFullScreen()
        onCloseWindowRequested: root.requestWindowClose()
        onWindowRequested: function (action) {
            if (action === "minimize") {
                root.showMinimized();
            } else if (root.visibility === Window.Maximized) {
                root.showNormal();
            } else {
                root.showMaximized();
            }
        }
        onAboutRequested: windowDialogs.aboutDialog.open()
        // once pages have agreed, aboutToQuit saves the session and shuts CEF down
        onQuitRequested: root.quitAfterPageCheck()
    }

}
