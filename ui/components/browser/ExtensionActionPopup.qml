import QtQuick
import illuminate.ui

pragma ComponentBehavior: Bound

// An extension's action popup, floating over the page the way Chrome's does:
// sized to what its page lays out at, gone once focus moves anywhere else.
// The page acts on the tab it was opened for (see CefRenderProcessHandler).
Window {
    id: root

    property var extension: null
    property int tabId: -1           // browserId of the page it acts on
    property point anchor            // global point its top left hangs from
    property size contentSize: Qt.size(0, 0) // as the page reports it
    readonly property bool sized: contentSize.width > 0
    readonly property int edge: 1
    readonly property int screenMargin: 8
    readonly property int loadingSize: 44
    readonly property CefBrowser page: pageLoader.item as CefBrowser

    function show(extension, tabId, anchor) {
        root.dismiss();
        root.tabId = tabId;
        root.anchor = anchor;
        root.extension = extension;
        Logger.info("ExtensionPopup", "open " + extension.popupUrl + " for tab " + tabId
                    + " at " + anchor.x + "," + anchor.y);
        root.visible = true;
        root.requestActivate();
    }

    function dismiss() {
        root.visible = false;
        root.extension = null;
        root.contentSize = Qt.size(0, 0);
    }

    // stay over the page: what doesn't fit scrolls inside the popup
    readonly property real maxContentWidth: transientParent
        ? transientParent.x + transientParent.width - anchor.x - screenMargin - 2 * edge
        : contentSize.width
    readonly property real maxContentHeight: transientParent
        ? transientParent.y + transientParent.height - anchor.y - screenMargin - 2 * edge
        : contentSize.height

    flags: Qt.Tool | Qt.FramelessWindowHint
    color: "transparent"
    width: (sized ? Math.max(Math.min(contentSize.width, maxContentWidth), loadingSize) : loadingSize) + 2 * edge
    height: (sized ? Math.max(Math.min(contentSize.height, maxContentHeight), loadingSize) : loadingSize) + 2 * edge
    x: anchor.x
    y: anchor.y

    onActiveChanged: if (!active) focusCheck.restart()

    // Escape inside the page is handled by the page itself
    Shortcut {
        sequence: "Escape"
        onActivated: root.dismiss()
    }

    Connections {
        target: Browser
        function onActiveIndexChanged() { root.dismiss(); }
        function onSpaceChanged() { root.dismiss(); }
    }

    // focus moved: stay only if it is in the popup or its page
    Timer {
        id: focusCheck
        interval: 80
        onTriggered: {
            if (root.visible && !root.active && !(root.page && root.page.hasNativeFocus()))
                root.dismiss();
        }
    }

    // after the page shows, so its window can take focus
    Timer {
        id: focusPage
        interval: 60
        onTriggered: if (root.page) root.page.takeFocus()
    }

    // a page that never reports a size still gets shown
    Timer {
        interval: 1500
        running: root.visible && !root.sized
        onTriggered: {
            Logger.warning("ExtensionPopup", "no size reported by the page; using 360x480");
            root.contentSize = Qt.size(360, 480);
            focusPage.restart();
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusCard
        color: Theme.bg
        border.color: Theme.border
        border.width: root.edge

        Image {
            anchors.centerIn: parent
            width: Theme.faviconSize
            height: Theme.faviconSize
            visible: !root.sized
            source: root.extension ? root.extension.iconUrl : ""
            sourceSize.width: 2 * Theme.faviconSize
            sourceSize.height: 2 * Theme.faviconSize
            fillMode: Image.PreserveAspectFit
            asynchronous: true
        }
    }

    Loader {
        id: pageLoader
        anchors.fill: parent
        anchors.margins: root.edge
        active: root.extension !== null

        sourceComponent: CefBrowser {
            profile: Browser.webProfile
            actionTabId: root.tabId
            url: root.extension ? root.extension.popupUrl : ""
            // laid out while hidden, so the first size it reports is its own
            visible: root.sized
            lifecycleState: CefBrowser.Active
            backgroundColor: "white"
            cornerRadius: Theme.radiusCard - root.edge

            onContentSizeReported: (width, height) => {
                Logger.debug("ExtensionPopup", "page reports " + width + "x" + height
                            + ", window " + root.width + "x" + root.height);
                const first = !root.sized;
                root.contentSize = Qt.size(width, height);
                if (first)
                    focusPage.restart();
            }
            onCloseRequested: root.dismiss()
            onNativeFocusLost: focusCheck.restart()
            onNewWindowRequested: url => {
                root.dismiss();
                Browser.newTab(url.toString());
            }
            onJavaScriptConsoleMessage: (level, message, lineNumber, sourceId) => {
                Logger.debug("Extension", level + "/" + sourceId + ":" + lineNumber + " " + message);
            }
        }
    }
}
