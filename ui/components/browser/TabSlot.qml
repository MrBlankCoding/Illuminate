import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import illuminate.ui

pragma ComponentBehavior: Bound

// one per tab: the internal page or the web view
Item {
    id: root
    property var browserContext: Browser
    required property int index
    required property var model
    required property var browserWindow
    required property var viewStack
    readonly property var splitMemberIds: {
        if (!browserContext)
            return [];
        const revision = browserContext.sidebar.structureRevision;
        return revision >= 0 ? browserContext.sidebar.splitTabs(model.id) : [];
    }
    readonly property int splitMemberIndex: splitMemberIds ? splitMemberIds.indexOf(model.id) : -1
    readonly property bool activeTabHasWebView: {
        if (!browserContext)
            return false;
        const activeTab = browserContext.tabModel.tabAt(browserContext.tabModel.activeIndex);
        return activeTab && !InternalPages.isInternal(String(activeTab.url));
    }
    readonly property bool isActiveTab: index === (browserContext ? browserContext.tabModel.activeIndex : -1)
    // only the split the active tab belongs to is on screen; other splits wait
    readonly property bool inActiveSplit: {
        if (!browserContext || splitMemberIndex < 0)
            return false;
        const activeTab = browserContext.tabModel.tabAt(browserContext.tabModel.activeIndex);
        return !!activeTab && splitMemberIds.indexOf(activeTab.id) >= 0;
    }
    readonly property real splitGap: splitMemberIndex >= 0 ? 8 : 0
    x: splitMemberIndex === 1 ? parent.width / 2 + splitGap / 2 : 0
    width: splitMemberIndex < 0 ? parent.width
        : parent.width / 2 - splitGap / 2
    height: parent.height
    visible: isActiveTab || inActiveSplit

    function refreshNativeView() {
        if (!root.webView || !root.visible || !root.browserContext)
            return;
        const shouldRaise = root.index === root.browserContext.tabModel.activeIndex;
        root.webView.refreshNativeView(shouldRaise);
    }

    onSplitMemberIndexChanged: {
        Qt.callLater(root.refreshNativeView);
    }

    Connections {
        target: root.browserContext ? root.browserContext.tabModel : null
        function onActiveIndexChanged() {
            if (root.splitMemberIndex >= 0
                    && root.index === root.browserContext.tabModel.activeIndex)
                Qt.callLater(root.refreshNativeView);
        }
    }

    TapHandler {
        enabled: root.splitMemberIndex >= 0
        onTapped: if (root.browserContext)
            root.browserContext.activateTab(root.index)
    }

    readonly property bool isInternalPage: InternalPages.isInternal(model.url.toString())
    readonly property string tabUrl: model.url.toString()
    onIsInternalPageChanged: {
        if (isInternalPage && browserContext)
            browserContext.updateTabRenderProcessPid(model.id, 0);
        Qt.callLater(syncWebViewUrl);
    }

    function syncBundledIcon() {
        if (!root.browserContext)
            return;
        const icon = InternalPages.iconUrl(root.tabUrl);
        const existingIcon = String(root.model.iconUrl || "");
        if (icon !== "" || existingIcon.startsWith("qrc:/illuminate/ui/icons/"))
            root.browserContext.updateTabIcon(root.model.id, icon);
    }
    function syncWebViewUrl() {
        if (root.isInternalPage || !webLoader.item)
            return;

        const targetTab = root.browserContext
            ? root.browserContext.tabModel.tabAt(root.index) : null;
        if (!targetTab || String(targetTab.id) !== String(root.model.id))
            return;

        const targetUrl = root.model.url;
        if (!targetUrl || targetUrl.toString() === "")
            return;

        webLoader.item.ownerTabId = String(root.model.id);
        targetTab.setCefBrowserWrapper(webLoader.item);
        if (root.model.suspended && root.index !== root.browserContext.tabModel.activeIndex
            && root.splitMemberIndex < 0)
            return;
        if (webLoader.item.url.toString() !== targetUrl.toString())
            webLoader.item.url = targetUrl;
    }

    onTabUrlChanged: {
        syncBundledIcon();
        Qt.callLater(syncWebViewUrl);
    }
    onModelChanged: Qt.callLater(syncWebViewUrl)
    Component.onCompleted: syncBundledIcon()
    function syncRenderPid() {
        if (browserContext)
            browserContext.updateTabRenderProcessPid(root.webView ? root.webView["ownerTabId"] : root.model.id, // qmllint disable missing-property
                                                     root.webView ? root.webView.renderProcessPid : 0)
    }

    function adoptWarmPage(view) {
        const warm = root.browserWindow ? root.browserWindow.warmSpaces : null;
        const context = root.browserContext;
        if (!warm || !context || !context.space || root.index !== context.tabModel.activeIndex)
            return;
        const page = warm.claim(context.space.id, root.model.url.toString());
        if (!page)
            return;
        if (view.adoptPage(page))
            Logger.debug("WebView", "Tab " + root.index + " took over its space's waiting page");
        page.destroy();
    }

    readonly property CefBrowser webView: webLoader.item as CefBrowser
    onWebViewChanged: {
        Qt.callLater(root.syncWebViewUrl)
        Qt.callLater(root.refreshNativeView)
        viewStack.refreshActiveWebView()
    }

    Loader {
        anchors.fill: parent
        active: root.isInternalPage
        visible: root.isInternalPage
        source: root.isInternalPage ? InternalPages.qmlSource(root.model.url.toString()) : ""
        onLoaded: {
            if (root.browserContext)
                root.browserContext.updateTabTitle(root.model.id, InternalPages.title(root.model.url.toString()));
            root.syncBundledIcon();
            // pages that act on their own tab (the crash page's Reload)
            if (item && item.hasOwnProperty("tabId"))
                item.tabId = Qt.binding(() => String(root.model.id));
            if (item && item.hasOwnProperty("pageUrl"))
                item.pageUrl = Qt.binding(() => root.tabUrl);
        }
    }

    Loader {
        id: webLoader
        anchors.fill: parent
        active: !root.isInternalPage && (!root.model.suspended || root.splitMemberIndex >= 0)
        visible: !root.isInternalPage

        onLoaded: {
            root.syncWebViewUrl();
        }

        sourceComponent: Component {
            CefBrowser {
                id: webView
                property string ownerTabId: ""
                profile: root.browserContext ? root.browserContext.webProfile : null
                anchors.fill: parent
                visible: root.visible
                keepVisibleWhileLoading: !root.visible && webView.loading && root.activeTabHasWebView
                inputSuppressed: root.browserWindow.inputOverlayOpen && root.isActiveTab
                focusTarget: root.isActiveTab
                lifecycleState: webView.visible
                    ? CefBrowser.Active
                    : CefBrowser.Frozen
                onLifecycleStateChanged: root.syncRenderPid()
                onNativeFocusRequested: {
                    if (root.isActiveTab) {
                        root.browserWindow.returnFocusToWeb();
                        return;
                    }
                    // the other half of a split: once the person has clicked
                    // into it, it becomes the tab ⌘L, reload and the rest act on.
                    // A page merely loading there doesn't hold key, so it can't
                    // take over the active tab or close an open overlay.
                    Qt.callLater(() => {
                        if (!root.browserContext || root.splitMemberIndex < 0 || !webView.hasNativeFocus())
                            return;
                        root.browserContext.activateTab(root.index);
                        root.browserWindow.returnFocusToWeb();
                    });
                }
                // the speaker on the tab, and its mute
                audioMuted: root.model.muted === true
                onAudibleChanged: {
                    if (root.browserContext)
                        root.browserContext.updateTabAudible(webView.ownerTabId, webView.audible);
                }
                Component.onDestruction: {
                    if (root.browserContext && webView.audible)
                        root.browserContext.updateTabAudible(webView.ownerTabId, false);
                }
                backgroundColor: Theme.bg
                cornerRadius: root.viewStack.cornerRadius
                Component.onCompleted: {
                    ownerTabId = root.model.id;
                    Logger.debug("Diag", "Tab " + root.index + " webview Component.onCompleted id=" + ownerTabId + " visible=" + root.visible + " url=" + webView.url);
                    Logger.debug("WebView", "Tab " + root.index + " created");
                    const browserTab = root.browserContext ? root.browserContext.tabModel.tabAt(root.index) : null;
                    if (browserTab && browserTab.id === ownerTabId) {
                        browserTab.setCefBrowserWrapper(webView);
                    }
                    root.adoptWarmPage(webView);
                    Logger.debug("Diag", "Tab " + root.index + " after adoptWarmPage url=" + webView.url + " loading=" + webView.loading);
                }

                onVisibleChanged: Logger.debug("Diag", "Tab " + root.index + " webView.visible=" + webView.visible + " root.visible=" + root.visible)
                onWidthChanged: Logger.debug("Diag", "Tab " + root.index + " webView.size=" + webView.width + "x" + webView.height)
                onHeightChanged: Logger.debug("Diag", "Tab " + root.index + " webView.size=" + webView.width + "x" + webView.height)

                onLoadingChanged: function () {
                    Logger.debug("Diag", "Tab " + root.index + " onLoadingChanged loading=" + webView.loading + " url=" + webView.url + " visible=" + root.visible + " webView.visible=" + webView.visible + " size=" + webView.width + "x" + webView.height);
                    if (root.browserContext)
                        root.browserContext.updateTabLoading(webView.ownerTabId, webView.loading);
                    root.syncRenderPid();
                    if (webView.loading)
                        Logger.debug("WebView", "Tab " + root.index + " loading");
                    else if (root.visible)
                        Qt.callLater(root.refreshNativeView);
                }

                onJavaScriptConsoleMessage: function (level, message, lineNumber, sourceId) {
                    const msg = String(message)
                    if (level === 0)
                        return
                    const text = level + "/" + sourceId + ":" + lineNumber + " " + msg
                    if (msg.indexOf("Error with Permissions-Policy header: Unrecognized feature:") >= 0) {
                        Logger.warning("WebConsole", text)
                        return
                    }
                    if (String(sourceId).startsWith("chrome-extension://")) {
                        Logger.debug("ExtensionConsole", text)
                        return
                    }
                    if (level >= 3)
                        Logger.error("WebView", text)
                    else
                        Logger.warning("WebView", text)
                }

                onUrlChanged: function () {
                    Logger.debug("Diag", "Tab " + root.index + " onUrlChanged url=" + webView.url);
                    if (root.browserContext)
                        root.browserContext.updateTabUrl(webView.ownerTabId, webView.url.toString());
                }

                onLoadProgressChanged: function (p) { if (root.browserContext) root.browserContext.updateTabProgress(webView.ownerTabId, p) }
                onRenderProcessPidChanged: root.syncRenderPid()
                onTitleChanged: if (root.browserContext) root.browserContext.updateTabTitle(webView.ownerTabId, webView.title)
                onIconChanged: {
                    if (!root.browserContext)
                        return;
                    const bundled = InternalPages.iconUrl(root.tabUrl);
                    const icon = webView.icon.toString();
                    root.browserContext.updateTabIcon(webView.ownerTabId, icon !== "" ? icon : bundled);
                }

                // the page agreed to close, or closed itself with window.close()
                onCloseApproved: {
                    if (root.browserContext)
                        root.browserContext.onTabCloseApproved(webView.ownerTabId);
                }
                onCloseCancelled: {
                    if (root.browserContext)
                        root.browserContext.onTabCloseCancelled(webView.ownerTabId);
                }
                // "Leave site?": bring the tab forward so it's clear which page asks
                onBeforeUnloadRequested: function (request) {
                    if (root.browserContext) {
                        root.browserContext.onTabBeforeUnloadShown(webView.ownerTabId);
                        if (root.index !== root.browserContext.tabModel.activeIndex)
                            root.browserContext.activateTab(root.index);
                    }
                    beforeUnloadPrompt.show(request);
                }

                onNewWindowRequested: function (url, background) {
                    if (root.browserContext)
                        root.browserContext.openTabFrom(webView.ownerTabId, url.toString(), background);
                }

                // pages calling window.print() open the system print dialog
                onPrintRequested: root.browserWindow.openSystemPrintFor(webView)
                onPdfPrintingFinished: (filePath, success) => root.browserWindow.onPdfPrintingFinished(filePath, success)

                onPermissionRequested: function (permission) {
                    permissionPrompt.handlePermission(permission)
                }

                Connections {
                    target: root.browserContext
                    function onLoadRequested(tabId, url) {
                        if (tabId !== webView.ownerTabId)
                            return;
                        if (webLoader.item)
                            webLoader.item.url = url;
                    }
                    function onNavigationRequested(tabId, action) {
                        if (tabId !== webView.ownerTabId)
                            return;
                        if (action === "back")
                            webView.goBack();
                        else if (action === "forward")
                            webView.goForward();
                        else if (action === "reload")
                            webView.reload();
                        else if (action === "stop")
                            webView.stop();
                        else if (action === "devtools")
                            webView.toggleDevTools();
                    }
                }

                Connections {
                    target: webView
                    function onLoadRequested(url) {
                        if (!root.browserContext || !webView.ownerTabId)
                            return;
                        const destination = url.toString();
                        root.browserContext.updateTabUrl(webView.ownerTabId, destination);
                        root.browserContext.updateTabTitle(webView.ownerTabId,
                            InternalPages.title(destination) || "New Tab");
                        root.browserContext.updateTabLoading(webView.ownerTabId, false);
                        root.browserContext.updateTabProgress(webView.ownerTabId, 0);
                        root.browserContext.updateTabRenderProcessPid(webView.ownerTabId, 0);
                    }
                }
            }
        }
    }

    PermissionPrompt {
        id: permissionPrompt
        anchors.fill: parent
        tabSlot: root
    }

    BeforeUnloadPrompt {
        id: beforeUnloadPrompt
        tabSlot: root
    }

}
