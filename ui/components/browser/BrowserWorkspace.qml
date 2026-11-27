import QtQuick
import QtQuick.Layouts
import illuminate.ui

pragma ComponentBehavior: Bound

Item {
    id: root
    required property var browserWindow
    required property var themePicker

    property alias viewStack: viewStack
    property alias dockLoader: dockLoader
    property alias warmSpaces: warmSpaces
    readonly property real dockWidth: dock.fullWidth

    function stopDockSlideOut() { dockSlideOut.stop(); }
    function startDockSlideOut() { dockSlideOut.start(); }
    function startDockSlideIn() { dockSlideIn.start(); }

    anchors.fill: parent

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Item {
            id: dock
            Layout.fillHeight: true
            readonly property real fullWidth: dockLoader.status === Loader.Ready ? dockLoader.item["implicitWidth"] : 0 // qmllint disable missing-property
            property real targetWidth: root.browserWindow.sidebarDockCollapsed || root.browserWindow.contentFullScreen
                ? 0 : fullWidth
            Layout.preferredWidth: targetWidth
            clip: true
            visible: targetWidth > 0 || width > 0

            ParallelAnimation {
                id: dockSlideIn
                NumberAnimation {
                    target: dockLoader
                    property: "x"
                    to: 0
                    duration: 220
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: dockLoader
                    property: "opacity"
                    to: 1
                    duration: 180
                    easing.type: Easing.OutCubic
                }
            }

            ParallelAnimation {
                id: dockSlideOut
                NumberAnimation {
                    target: dockLoader
                    property: "x"
                    to: -dockLoader.width
                    duration: 190
                    easing.type: Easing.InCubic
                }
                NumberAnimation {
                    target: dockLoader
                    property: "opacity"
                    to: 0
                    duration: 150
                    easing.type: Easing.InCubic
                }
                onFinished: {
                    root.browserWindow.sidebarDockCollapsed = true;
                }
            }

            Loader {
                id: dockLoader
                width: dock.fullWidth
                height: parent.height
                sourceComponent: sidebarComponent
                Component.onCompleted: {
                    x = Qt.binding(() => root.browserWindow.sidebarDockCollapsed ? -dockLoader.width : 0);
                    opacity = Qt.binding(() => root.browserWindow.sidebarDockCollapsed ? 0 : 1);
                }
                onWidthChanged: if (root.browserWindow.sidebarDockCollapsed && !dockSlideOut.running)
                    x = Qt.binding(() => -dockLoader.width);
            }
        }

        WebContentCard {
            id: card
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: root.browserWindow.contentFullScreen ? 0 : Theme.cardMargin
            radius: root.browserWindow.contentFullScreen ? 0 : Theme.radiusCard
            shadowEnabled: !root.browserWindow.contentFullScreen
            roundContent: InternalPages.isInternal(Browser.activeUrl)

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // content area
                Item {
                    id: viewStack
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    property CefBrowser activeWebView: null
                    readonly property real cornerRadius: card.radius


                    function refreshActiveWebView() {
                        const tab = viewRepeater.itemAt(Browser.tabModel.activeIndex) as TabSlot;
                        const next = tab ? tab.webView : null;
                        if (viewStack.activeWebView && viewStack.activeWebView !== next && viewStack.activeWebView.fullScreen)
                            viewStack.activeWebView.exitFullScreen();
                        viewStack.activeWebView = next;
                    }

                    Component.onCompleted: {
                        Qt.callLater(viewStack.refreshActiveWebView);
                        if (activeSplitIds.length === 2)
                            Browser.sidebar.prepareSplit(activeSplitIds[0]);
                    }


                    Connections {
                        target: Browser
                        enabled: !root.browserWindow.retiring
                        function onActiveIndexChanged() {
                            viewStack.refreshActiveWebView();
                        }
                        function onNewTabOpened() {
                            root.browserWindow.openCommandBar("new");
                        }

                        function onCloseWindowRequested() {
                            root.browserWindow.requestWindowClose();
                        }

                    }

                    Repeater {
                        id: viewRepeater
                        model: root.browserWindow.retiring ? null : Browser.tabModel

                        delegate: TabSlot {
                            browserWindow: root.browserWindow
                            viewStack: root.viewStack
                        }

                        onItemAdded: viewStack.refreshActiveWebView()
                        onItemRemoved: viewStack.refreshActiveWebView()
                    }

                    // other spaces' last pages, running hidden at this size
                    WarmSpaces {
                        id: warmSpaces
                        anchors.fill: parent
                        activeWebView: viewStack.activeWebView
                    }

                    Connections {
                        target: Browser.tabModel
                        function onRowsMoved() {
                            // Reordering can change delegate stacking without
                            // changing the active index. Restore the selected
                            // native CEF view after the delegates settle.
                            Qt.callLater(() => {
                                viewStack.refreshActiveWebView();
                                if (viewStack.activeWebView)
                                    viewStack.activeWebView.refreshNativeView(true);
                            });
                        }
                    }

                    readonly property var activeSplitIds: {
                        const tab = Browser.tabModel.tabAt(Browser.tabModel.activeIndex);
                        const revision = Browser.sidebar.structureRevision;
                        return tab && revision >= 0 ? Browser.sidebar.splitTabs(tab.id) : [];
                    }
                    readonly property string activeSplitKey: activeSplitIds.join("|")
                    onActiveSplitKeyChanged: if (activeSplitIds.length === 2)
                        Browser.sidebar.prepareSplit(activeSplitIds[0]);
                }
            }
        }
    }

    Component {
        id: sidebarComponent

        Sidebar {
            targetWindow: root.browserWindow
            themePicker: root.themePicker
            currentUrl: Browser.activeUrl === "newtab://newtab" ? "" : Browser.activeUrl
            currentTitle: Browser.activeTitle
            currentIconUrl: Browser.activeIconUrl
            isLoading: Browser.activeLoading
            loadProgress: Browser.activeProgress
            canGoBack: viewStack.activeWebView ? viewStack.activeWebView.canGoBack : false
            canGoForward: viewStack.activeWebView ? viewStack.activeWebView.canGoForward : false

            onOpenSettings: root.browserWindow.openSettings()
            onCommandBarRequested: mode => root.browserWindow.openCommandBar(mode)
            onToggleCollapsed: root.browserWindow.toggleSidebar()
        }
    }

    // the window can still be dragged by its top edge while collapsed
    WindowDragRegion {
        x: 0
        y: 0
        width: parent.width
        height: Theme.cardMargin
        visible: root.browserWindow.sidebarCollapsed && !root.browserWindow.contentFullScreen
    }

}
